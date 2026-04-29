//
//  SubscriptionView.swift
//  shishanyouni
//
//  Created by Codex on 2026/4/29.
//

import StoreKit
import SwiftUI

struct SubscriptionView: View
{
    @EnvironmentObject var store: IAPStore

    var body: some View
    {
        ScrollView
        {
            VStack(alignment: .leading, spacing: 20)
            {
                headerSection
                productSection
                testingGuideSection
            }
            .padding(20)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.orange.opacity(0.12),
                    Color.blue.opacity(0.08),
                    Color.white,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .navigationTitle("校园通行证服务")
        .navigationBarTitleDisplayMode(.inline)
        .task
        {
            if store.products.isEmpty
            {
                await store.bootstrap()
            }
        }
    }

    private var headerSection: some View
    {
        VStack(alignment: .leading, spacing: 14)
        {
            Text("💳 购买狮山有你通行证")
                .font(.system(size: 30, weight: .bold, design: .rounded))

            Text("先把本地 StoreKit 跑通，后面接真实 App Store Connect 时就不会一脸懵。")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            HStack(spacing: 12)
            {
                statusPill(
                    title: store.hasActiveSubscription ? "订阅已激活" : "尚未订阅",
                    color: store.hasActiveSubscription ? .green : .red
                )

                statusPill(
                    title: store.isLoadingProducts ? "读取商品中" : "商品已加载",
                    color: store.isLoadingProducts ? .orange : .blue
                )
            }

            Text(store.statusMessage)
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }

    private var productSection: some View
    {
        VStack(alignment: .leading, spacing: 14)
        {
            Text("订阅选项")
                .font(.title3.bold())

            if store.products.isEmpty
            {
                VStack(alignment: .leading, spacing: 10)
                {
                    Text("还没读到订阅商品")
                        .font(.headline)
                    Text("大概率是当前 Scheme 没绑 `StoreKitConfig.storekit`，下面我把完整流程也写给你了。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
            }
            else
            {
                ForEach(store.products, id: \.id)
                { product in
                    subscriptionCard(for: product)
                }
            }

            Button
            {
                Task
                {
                    await store.restorePurchases()
                }
            } label: {
                Text("恢复购买")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
        }
    }

    private var testingGuideSection: some View
    {
        VStack(alignment: .leading, spacing: 12)
        {
            Text("本地测试流程")
                .font(.title3.bold())

            guideRow(index: 1, text: "在 Xcode 顶部选中 `shishanyouni` scheme，然后点 `Edit Scheme...`。")
            guideRow(index: 2, text: "切到 `Run -> Options`，把 `StoreKit Configuration` 设成 `shishanyouni/IAP/StoreKitConfig.storekit`。")
            guideRow(index: 3, text: "重新运行 App，进入这个页面后应该能看到两个商品。")
            guideRow(index: 4, text: "点击购买，系统会弹本地测试购买面板；确认后状态会变成已订阅。")
            guideRow(index: 5, text: "想重测就用 Xcode 菜单 `Debug -> StoreKit -> Manage Transactions` 删除交易，或者点 `Sync` 恢复。")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }

    private func subscriptionCard(for product: Product) -> some View
    {
        let copy = store.copy(for: product.id)
        let purchased = store.isPurchased(product.id)

        return VStack(alignment: .leading, spacing: 14)
        {
            HStack(alignment: .top)
            {
                VStack(alignment: .leading, spacing: 6)
                {
                    Text(copy.title)
                        .font(.title3.bold())
                    Text(copy.subtitle)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if purchased
                {
                    Label("已订阅", systemImage: "checkmark.seal.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.green)
                }
            }

            HStack(alignment: .lastTextBaseline)
            {
                Text(product.displayPrice)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(periodText(for: product.id))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Button
            {
                Task
                {
                    await store.purchase(product)
                }
            } label: {
                Text(purchased ? "当前方案已生效" : "购买并测试")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        purchaseBackgroundStyle(purchased: purchased, accent: copy.accent),
                        in: RoundedRectangle(cornerRadius: 18)
                    )
                    .foregroundColor(purchased ? .green : .white)
            }
            .buttonStyle(.plain)
            .disabled(store.isPurchasing || purchased)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    private func guideRow(index: Int, text: String) -> some View
    {
        HStack(alignment: .top, spacing: 12)
        {
            Text("\(index)")
                .font(.footnote.bold())
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(Color.orange, in: Circle())

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.primary)
        }
    }

    private func statusPill(title: String, color: Color) -> some View
    {
        Text(title)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundColor(color)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func periodText(for productID: String) -> String
    {
        switch productID
        {
        case IAPStore.semesterProductID:
            return "/ 每学期"
        case IAPStore.yearProductID:
            return "/ 每年"
        default:
            return ""
        }
    }

    private func purchaseGradient(for accent: String) -> LinearGradient
    {
        switch accent
        {
        case "semester":
            return LinearGradient(
                colors: [Color.orange, Color.red],
                startPoint: .leading,
                endPoint: .trailing
            )
        case "year":
            return LinearGradient(
                colors: [Color.blue, Color.cyan],
                startPoint: .leading,
                endPoint: .trailing
            )
        default:
            return LinearGradient(
                colors: [Color.gray, Color.gray.opacity(0.7)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    private func purchaseBackgroundStyle(purchased: Bool, accent: String) -> AnyShapeStyle
    {
        if purchased
        {
            return AnyShapeStyle(Color.green.opacity(0.18))
        }

        return AnyShapeStyle(purchaseGradient(for: accent))
    }
}

struct SubscriptionView_Previews: PreviewProvider
{
    static var previews: some View
    {
        NavigationStack
        {
            SubscriptionView()
                .environmentObject(IAPStore(autoload: false))
        }
    }
}
