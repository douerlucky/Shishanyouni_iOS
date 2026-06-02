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
    @Published private(set) var isPurchasing = false
    @Published var statusMessage = "正在加载校园通行证商品..."

    private let productIDs = [
        IAPStore.monthProductID,
        IAPStore.halfYearProductID,
    ]
    private var updatesTask: Task<Void, Never>?
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
        await refreshEntitlements()
        await loadProducts()
    }

    func loadProducts() async
    {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do
        {
            let fetchedProducts = try await Product.products(for: productIDs)
            products = fetchedProducts.sorted
            { lhs, rhs in
                productOrder(for: lhs.id) < productOrder(for: rhs.id)
            }

            if products.isEmpty
            {
                statusMessage = "暂时没有读取到校园通行证商品，请检查 ASC 商品是否已配置完成。"
            }
            else
            {
                statusMessage = hasActiveSubscription ? "已读取商品，并检测到当前有效的校园通行证权益。" : "已读取校园通行证商品。"
            }
        }
        catch
        {
            statusMessage = "商品加载失败：\(error.localizedDescription)"
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

        WidgetSharedStore.saveSubscriptionStatus(
            isActive: currentAccess != nil,
            productID: currentAccess?.productID,
            expiration: currentAccess?.expirationDate == .distantFuture ? nil : currentAccess?.expirationDate.timeIntervalSince1970
        )
    }

    var hasActiveSubscription: Bool
    {
#if DEBUG
        true
#else
        activeProductID != nil
#endif
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
                subtitle: "一个月畅享狮山有你所有Pro功能",
                accent: "month"
            )
        case IAPStore.halfYearProductID:
            return ProductCopy(
                title: "校园通行证一学期（6个月）",
                subtitle: "一学期畅享狮山有你所有Pro功能",
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
