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
                comparisonSection
                supportNoticeSection
            }
            .padding(20)
        }
        .background(
            LinearGradient(
                colors: [
                    themePrimary.opacity(0.18),
                    themePrimary.opacity(0.08),
                    Color.white,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("校园通行证服务")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
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
            Text("购买狮山有你iOS通行证")
                .font(.system(size: 30, weight: .bold, design: .rounded))

            Text("开发iOS版不易，感谢使用，我们保证所有小程序的功能iOS版全部免费。开通后即可解锁狮山有你iOS校园通行证权益，享受更完整的iOS版专属功能体验。")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            HStack(spacing: 12)
            {
                statusPill(
                    title: store.hasActiveSubscription ? "已是狮山有你iOS校园通行证用户" : "尚未开通",
                    color: store.hasActiveSubscription ? .green : .red
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
        )
    }

    private var productSection: some View
    {
        VStack(alignment: .leading, spacing: 14)
        {
            Text("通行证选项")
                .font(.title3.bold())

            if store.products.isEmpty
            {
                VStack(alignment: .leading, spacing: 10)
                {
                    Text("商品信息准备中")
                        .font(.headline)
                    Text("当前暂时未读取到可购买的校园通行证商品，请稍后重试。")
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
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(themePrimary.opacity(0.18), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var comparisonSection: some View
    {
        VStack(alignment: .leading, spacing: 14)
        {
            Text("功能对比")
                .font(.title3.bold())

            VStack(spacing: 0)
            {
                comparisonHeaderRow

                ForEach(comparisonRows, id: \.title)
                { row in
                    comparisonRow(row)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(themePrimary.opacity(0.10), lineWidth: 1)
            )
        }
    }

    private var supportNoticeSection: some View
    {
        VStack(alignment: .leading, spacing: 12)
        {
            Text("说明")
                .font(.title3.bold())

            VStack(alignment: .leading, spacing: 10)
            {
                Text("狮山有你iOS校园通行证仅可在狮山有你iOS App内使用。")
                Text("当前校园通行证为自动续期订阅，可在 Apple 订阅管理中随时取消续费。")
                Text("狮山有你iOS版与狮山有你微信小程序、狮山有你Android App并非同一开发团队。")
                Text("狮山有你iOS版遇到的问题，请联系沸点工作室移动App开发组。")
                Text("狮山有你iOS版相关功能由iOS开发团队负责解释与后续更新。")
            }
            .font(.system(size: 14))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(themePrimary.opacity(0.10), lineWidth: 1)
            )
        }
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
                    Label("当前生效", systemImage: "checkmark.seal.fill")
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
                Text(purchased ? "当前方案生效中" : "立即开通")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        purchaseBackgroundStyle(purchased: purchased),
                        in: RoundedRectangle(cornerRadius: 18)
                    )
                    .foregroundColor(purchased ? themePrimary : .white)
            }
            .buttonStyle(.plain)
            .disabled(store.isPurchasing || purchased)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(themePrimary.opacity(0.10), lineWidth: 1)
        )
    }

    private var comparisonHeaderRow: some View
    {
        HStack(spacing: 0)
        {
            comparisonCell("功能", alignment: .leading, isHeader: true)
            comparisonCell("普通用户", alignment: .center, isHeader: true, width: 76)
            comparisonCell("通行证用户", alignment: .center, isHeader: true, width: 92)
        }
        .padding(.top, 6)
    }

    private func comparisonRow(_ row: ComparisonRow) -> some View
    {
        HStack(spacing: 0)
        {
            comparisonCell(row.title, alignment: .leading)
            comparisonMarkCell(row.normalUserAvailable, width: 76)
            comparisonMarkCell(row.passUserAvailable, width: 92)
        }
        .overlay(alignment: .top)
        {
            Divider()
                .overlay(themePrimary.opacity(0.08))
        }
    }

    private func comparisonCell(
        _ text: String,
        alignment: Alignment,
        isHeader: Bool = false,
        width: CGFloat? = nil
    ) -> some View
    {
        Text(text)
            .font(.system(size: isHeader ? 14 : 13, weight: isHeader ? .semibold : .regular))
            .foregroundColor(.primary)
            .multilineTextAlignment(alignment == .leading ? .leading : .center)
            .frame(width: width, alignment: alignment)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: alignment)
            .frame(minHeight: 54, alignment: alignment)
            .padding(.horizontal, width == nil ? 14 : 8)
            .padding(.vertical, 6)
    }

    private func comparisonMarkCell(_ available: Bool, width: CGFloat = 88) -> some View
    {
        Image(systemName: available ? "checkmark" : "xmark")
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(available ? themePrimary : .secondary.opacity(0.65))
            .frame(width: width)
            .frame(minHeight: 54)
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
        case IAPStore.monthProductID:
            return "/ 每月"
        case IAPStore.halfYearProductID:
            return "/ 每6个月"
        default:
            return ""
        }
    }

    private var themePrimary: Color
    {
        Color(red: 23 / 255, green: 144 / 255, blue: 204 / 255)
    }

    private func purchaseBackgroundStyle(purchased: Bool) -> AnyShapeStyle
    {
        if purchased
        {
            return AnyShapeStyle(themePrimary.opacity(0.12))
        }

        return AnyShapeStyle(themePrimary)
    }
}

private extension SubscriptionView
{
    struct ComparisonRow
    {
        let title: String
        let normalUserAvailable: Bool
        let passUserAvailable: Bool
    }

    var comparisonRows: [ComparisonRow]
    {
        [
            ComparisonRow(title: "所有狮山有你小程序功能", normalUserAvailable: true, passUserAvailable: true),
            ComparisonRow(title: "体测查询", normalUserAvailable: false, passUserAvailable: true),
            ComparisonRow(title: "ITC平台查询", normalUserAvailable: false, passUserAvailable: true),
            ComparisonRow(title: "桌面小组件（即将推出）", normalUserAvailable: false, passUserAvailable: true),
            ComparisonRow(title: "私人行程与日程", normalUserAvailable: false, passUserAvailable: true),
            ComparisonRow(title: "后续iOS版专属功能更新", normalUserAvailable: false, passUserAvailable: true),
        ]
    }
}

struct SubscriptionView_Previews: PreviewProvider
{
    static var previews: some View
    {
        NavigationStack
        {
            SubscriptionView()
                .environmentObject(IAPStore())
        }
    }
}
