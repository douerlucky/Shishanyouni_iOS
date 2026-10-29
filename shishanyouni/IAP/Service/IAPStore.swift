//
//  IAPStore.swift
//  shishanyouni
//
//  Created by Codex on 2026/4/29.
//

import Foundation
import StoreKit

@MainActor
final class IAPStore: ObservableObject
{
    static let shared = IAPStore()

    struct ProductCopy
    {
        let title: String
        let subtitle: String
        let accent: String
    }

    static let monthProductID = "com.shishanyouni.vip.month_vip"
    static let halfYearProductID = "com.shishanyouni.vip.six_month_vip"

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var activeProductID: String?
    @Published private(set) var activeExpirationDate: Date?
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var productLoadError: String?
    @Published private(set) var storefrontCountryCode: String?
    @Published private(set) var isPurchasing = false
    @Published var statusMessage = "正在加载校园通行证商品..."

    private var previewSubscriptionOverride: Bool?

    private let productIDs = [
        IAPStore.monthProductID,
        IAPStore.halfYearProductID,
    ]
    private var updatesTask: Task<Void, Never>?
    private var activeProductLoadID: UUID?
    init(autoload: Bool = true)
    {
        guard autoload else { return }

        updatesTask = observeTransactionUpdates()

        Task
        {
            await bootstrap()
        }
    }

    deinit
    {
        updatesTask?.cancel()
    }

    func bootstrap() async
    {
        // 两条 StoreKit 请求互不依赖；商品读取即使卡住，也能按时显示重试入口。
        async let entitlements: Void = refreshEntitlements()
        async let availableProducts: Void = loadProducts()
        _ = await (entitlements, availableProducts)
    }

    func loadProducts() async
    {
        guard !isLoadingProducts else { return }

        let loadID = UUID()
        activeProductLoadID = loadID
        isLoadingProducts = true
        productLoadError = nil
        storefrontCountryCode = nil
        let startedAt = Date()

        // StoreKit 偶尔不会及时返回；超时只切换页面状态，迟到的结果仍可正常更新。
        let timeoutTask = Task
        {
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            guard !Task.isCancelled, activeProductLoadID == loadID, isLoadingProducts else { return }
            isLoadingProducts = false
            productLoadError = "连接 App Store 超时，请稍后重试。"
            statusMessage = productLoadError ?? ""
            print("[StoreKit] product request timed out after 15s, storefront=\(storefrontCountryCode ?? "nil")")
        }
        defer { timeoutTask.cancel() }

        do
        {
            let storefront = await Storefront.current
            guard activeProductLoadID == loadID else { return }
            storefrontCountryCode = storefront?.countryCode

            let fetchedProducts = try await Product.products(for: productIDs)
            guard activeProductLoadID == loadID else { return }

            isLoadingProducts = false
            products = fetchedProducts.sorted
            { lhs, rhs in
                productOrder(for: lhs.id) < productOrder(for: rhs.id)
            }
            print("[StoreKit] elapsed=\(Date().timeIntervalSince(startedAt))s, storefront=\(storefront?.countryCode ?? "nil") (\(storefront?.id ?? "nil")), requested=\(productIDs), returned=\(products.map(\.id))")

            if products.isEmpty
            {
                productLoadError = "App Store 当前未返回校园通行证商品，请确认“媒体与购买项目”的账户及商店地区后重试。"
                statusMessage = productLoadError ?? ""
            }
            else
            {
                productLoadError = nil
                statusMessage = hasActiveSubscription ? "已读取商品，并检测到当前有效的校园通行证权益。" : "已读取校园通行证商品。"
            }
        }
        catch
        {
            guard activeProductLoadID == loadID else { return }
            isLoadingProducts = false
            productLoadError = "商品加载失败：\(error.localizedDescription)"
            statusMessage = "商品加载失败：\(error.localizedDescription)"
            print("[StoreKit] elapsed=\(Date().timeIntervalSince(startedAt))s, storefront=\(storefrontCountryCode ?? "nil"), requested=\(productIDs), error=\(error)")
        }
    }

    func purchase(_ product: Product) async
    {
        isPurchasing = true
        statusMessage = "正在开通：\(copy(for: product.id).title)"
        defer { isPurchasing = false }

        do
        {
            let result = try await product.purchase()

            switch result
            {
            case let .success(verificationResult):
                let transaction = try verify(verificationResult)
                statusMessage = "开通成功：\(copy(for: transaction.productID).title)"
                await transaction.finish()
                await refreshEntitlements()
            case .pending:
                statusMessage = "订单正在等待系统确认，稍后会自动刷新。"
            case .userCancelled:
                statusMessage = "你取消了这次开通。"
            @unknown default:
                statusMessage = "出现了未知购买状态。"
            }
        }
        catch
        {
            statusMessage = "购买失败：\(error.localizedDescription)"
        }
    }

    func restorePurchases() async
    {
        do
        {
            try await AppStore.sync()
            await refreshEntitlements()
            statusMessage = hasActiveSubscription ? "已同步购买记录" : "当前没有可同步的有效校园通行证权益。"
        }
        catch
        {
            statusMessage = "同步购买记录失败：\(error.localizedDescription)"
        }
    }

    func refreshEntitlements() async
    {
        var activeEntitlements: [(productID: String, expirationDate: Date)] = []
        let now = Date()

        for await result in Transaction.currentEntitlements
        {
            guard case let .verified(transaction) = result else { continue }
            let expirationDate = transaction.expirationDate ?? .distantFuture

            if expirationDate > now
            {
                activeEntitlements.append((transaction.productID, expirationDate))
            }
        }

        let currentAccess = activeEntitlements.max
        { lhs, rhs in
            lhs.expirationDate < rhs.expirationDate
        }

        activeProductID = currentAccess?.productID
        activeExpirationDate = currentAccess?.expirationDate
        purchasedProductIDs = currentAccess.map { [$0.productID] } ?? []

        IAPWidgetSync.saveSubscriptionStatus(
            isActive: currentAccess != nil,
            productID: currentAccess?.productID,
            expiration: currentAccess?.expirationDate == .distantFuture ? nil : currentAccess?.expirationDate.timeIntervalSince1970
        )
    }

    var hasActiveSubscription: Bool
    {
        previewSubscriptionOverride ?? (activeProductID != nil)
    }

    func isPurchased(_ productID: String) -> Bool
    {
        activeProductID == productID
    }

    func copy(for productID: String) -> ProductCopy
    {
        switch productID
        {
        case IAPStore.monthProductID:
            return ProductCopy(
                title: "校园通行证（1个月）",
                subtitle: "免费试用7天，之后¥6/月，可随时取消",
                accent: "month"
            )
        case IAPStore.halfYearProductID:
            return ProductCopy(
                title: "校园通行证一学期（6个月）",
                subtitle: "免费试用7天，之后¥30/6个月，可随时取消",
                accent: "halfyear"
            )
        default:
            return ProductCopy(
                title: productID,
                subtitle: "未知商品",
                accent: "default"
            )
        }
    }

    private func observeTransactionUpdates() -> Task<Void, Never>
    {
        Task.detached(priority: .background)
        { [weak self] in
            for await result in Transaction.updates
            {
                guard case let .verified(transaction) = result else { continue }
                await transaction.finish()
                await self?.refreshEntitlements()
            }
        }
    }

    private func verify<T>(_ result: VerificationResult<T>) throws -> T
    {
        switch result
        {
        case let .verified(safe):
            return safe
        case .unverified:
            throw StoreError.failedVerification
        }
    }

    private func productOrder(for productID: String) -> Int
    {
        productIDs.firstIndex(of: productID) ?? .max
    }

}

extension IAPStore
{
    static func preview(hasActiveSubscription: Bool = false) -> IAPStore
    {
        let store = IAPStore(autoload: false)
        store.previewSubscriptionOverride = hasActiveSubscription
        return store
    }
}

extension IAPStore
{
    enum StoreError: LocalizedError
    {
        case failedVerification

        var errorDescription: String?
        {
            switch self
            {
            case .failedVerification:
                return "交易校验失败，系统拒绝了这次购买。"
            }
        }
    }
}
