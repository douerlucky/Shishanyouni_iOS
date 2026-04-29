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
    struct ProductCopy
    {
        let title: String
        let subtitle: String
        let accent: String
    }

    static let semesterProductID = "com.shishanyouni.vip.semester"
    static let yearProductID = "com.shishanyouni.vip.year"

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published var statusMessage = "正在连接 App Store..."

    private let productIDs = [
        IAPStore.semesterProductID,
        IAPStore.yearProductID,
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
                statusMessage = "没有读取到订阅商品，请检查 Scheme 是否绑定了 StoreKitConfig.storekit"
            }
            else
            {
                statusMessage = hasActiveSubscription ? "已读取订阅并检测到有效会员" : "已读取订阅商品，可以开始本地测试"
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
        statusMessage = "正在发起购买：\(copy(for: product.id).title)"
        defer { isPurchasing = false }

        do
        {
            let result = try await product.purchase()

            switch result
            {
            case let .success(verificationResult):
                let transaction = try verify(verificationResult)
                purchasedProductIDs.insert(transaction.productID)
                statusMessage = "购买成功：\(copy(for: transaction.productID).title)"
                await transaction.finish()
                await refreshEntitlements()
            case .pending:
                statusMessage = "订单待处理，等系统确认后会自动刷新"
            case .userCancelled:
                statusMessage = "你取消了购买，哼"
            @unknown default:
                statusMessage = "出现了未知购买状态"
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
            statusMessage = hasActiveSubscription ? "已恢复购买记录" : "当前没有可恢复的有效订阅"
        }
        catch
        {
            statusMessage = "恢复购买失败：\(error.localizedDescription)"
        }
    }

    // 刷新状态
    func refreshEntitlements() async
    {
        var activeProductIDs: Set<String> = []

        for await result in Transaction.currentEntitlements
        {
            guard case let .verified(transaction) = result else { continue }
            activeProductIDs.insert(transaction.productID)
        }

        purchasedProductIDs = activeProductIDs

        //写入小组件的共享组
        WidgetSharedStore.saveSubscriptionStatus(
            isActive: !activeProductIDs.isEmpty,
            productID: activeProductIDs.first,
            expiration: nil
        )
    }

    var hasActiveSubscription: Bool
    {
        !purchasedProductIDs.isEmpty
    }

    func isPurchased(_ productID: String) -> Bool
    {
        purchasedProductIDs.contains(productID)
    }

    func copy(for productID: String) -> ProductCopy
    {
        switch productID
        {
        case IAPStore.semesterProductID:
            return ProductCopy(
                title: "校园通行证（一学期）",
                subtitle: "适合先试用一学期，把小组件和会员能力都跑通",
                accent: "semester"
            )
        case IAPStore.yearProductID:
            return ProductCopy(
                title: "校园通行证（一年）",
                subtitle: "更省心的一年订阅，后面做正式上架时也更像完整版套餐",
                accent: "year"
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
