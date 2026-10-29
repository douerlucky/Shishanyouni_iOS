import StoreKit
import SwiftUI
import UIKit
import WebKit

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
                legalLinksSection
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("校园通行证服务")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task
        {
            await store.bootstrap()
        }
    }

    private var headerSection: some View
    {
        VStack(alignment: .leading, spacing: 14)
        {
            Text("购买狮山有你iOS通行证")
                .font(.system(size: 30, weight: .bold, design: .rounded))

            Text("现在可免费试用7天，试用结束后按所选方案自动续费。你可以随时在 Apple 订阅管理中取消。")
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

            Button
            {
                // 直接调用 Apple 的系统优惠码兑换窗口。
                SKPaymentQueue.default().presentCodeRedemptionSheet()
            } label: {
                Label("兑换优惠码", systemImage: "appstore")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .nativeGlassButtonStyle(fillsWidth: true)
            .tint(themePrimary)
            .controlSize(.large)

            Text("自定义优惠码请在 App 内使用此入口，或打开兑换链接。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            NavigationLink
            {
                ShareRewardRedeemView()
                    .environmentObject(store)
            } label: {
                shareRewardEntryCard
            }
            .buttonStyle(.plain)

            if store.products.isEmpty
            {
                VStack(alignment: .leading, spacing: 10)
                {
                    if let error = store.productLoadError
                    {
                        Label("无法加载 App Store 商品信息", systemImage: "exclamationmark.triangle")
                            .font(.headline)
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Text("当前商店：\(store.storefrontCountryCode == "CHN" ? "中国大陆 (CHN)" : (store.storefrontCountryCode ?? "未获取到"))")
                            .font(.footnote)
                            .foregroundColor(.secondary)

                        Button("重新加载")
                        {
                            Task { await store.loadProducts() }
                        }
                        .nativeGlassButtonStyle(prominent: true)
                    }
                    else
                    {
                        ProgressView("正在获取 App Store 商品信息…")
                            .font(.headline)
                    }
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
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .nativeGlassButtonStyle(fillsWidth: true)
            .tint(themePrimary)
            .controlSize(.large)
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
                Text("当前校园通行证为自动续期订阅，新用户可免费试用7天，试用结束后按所选方案自动续费。")
                Text("订阅可在 Apple 订阅管理中随时取消；取消后仍可使用到当前试用期或已付费周期结束。")
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

    private var shareRewardEntryCard: some View
    {
        HStack(alignment: .top, spacing: 14)
        {
            ZStack
            {
                RoundedRectangle(cornerRadius: 16)
                    .fill(themePrimary.opacity(0.12))
                    .frame(width: 52, height: 52)

                Image(systemName: "megaphone.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(themePrimary)
            }

            VStack(alignment: .leading, spacing: 6)
            {
                Text("将狮山有你iOS版分享给社交平台")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("免费获得 3 个月通行证兑换码")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(themePrimary)

                Text("发布截图、带上话题限时领取兑换码。")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundColor(.secondary.opacity(0.7))
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

    private var legalLinksSection: some View
    {
        VStack(alignment: .leading, spacing: 12)
        {
            Text("法律与订阅说明")
                .font(.title3.bold())

            VStack(spacing: 0)
            {
                NavigationLink
                {
                    LocalHTMLDocumentView(
                        title: "隐私政策",
                        resourceName: "shishanyouni-ios-privacy-policy"
                    )
                } label: {
                    legalLinkRow(title: "隐私政策", subtitle: "查看狮山有你iOS版隐私说明")
                }
                .buttonStyle(.plain)

                Divider()
                    .overlay(themePrimary.opacity(0.08))

                Link(destination: appleStandardEULAURL) {
                    legalLinkRow(title: "服务条款（EULA）", subtitle: "查看 Apple 标准许可协议")
                }
                .buttonStyle(.plain)
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

            VStack(alignment: .leading, spacing: 6)
            {
                Label("免费试用 7 天", systemImage: "gift.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themePrimary)

                Text("试用结束后自动续费为 \(renewalPriceText(for: product.id))，你可以随时取消。")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(themePrimary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

            LiquidGlassCapsuleButton(
                title: purchased ? "当前方案生效中" : "开始免费试用",
                tint: themePrimary
            )
            {
                Task
                {
                    await store.purchase(product)
                }
            }
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

    private func legalLinkRow(title: String, subtitle: String) -> some View
    {
        HStack(spacing: 12)
        {
            Image(systemName: "doc.text")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(themePrimary)
                .frame(width: 34, height: 34)
                .background(themePrimary.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3)
            {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundColor(.secondary.opacity(0.65))
        }
        .padding(16)
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

    private func renewalPriceText(for productID: String) -> String
    {
        switch productID
        {
        case IAPStore.monthProductID:
            return "¥6/月"
        case IAPStore.halfYearProductID:
            return "¥30/6个月"
        default:
            return "所选价格"
        }
    }

    private var themePrimary: Color
    {
        appActionBlue
    }

    private var appleStandardEULAURL: URL
    {
        URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
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
            ComparisonRow(title: "私人日程与行程管理", normalUserAvailable: false, passUserAvailable: true),
            ComparisonRow(title: "成绩详情、学期分析与 GPA", normalUserAvailable: false, passUserAvailable: true),
            ComparisonRow(title: "体测查询", normalUserAvailable: false, passUserAvailable: true),
            ComparisonRow(title: "ITC 作业平台", normalUserAvailable: false, passUserAvailable: true),
            ComparisonRow(title: "选课功能", normalUserAvailable: false, passUserAvailable: true),
            ComparisonRow(title: "图书馆座位预约", normalUserAvailable: false, passUserAvailable: true),
            ComparisonRow(title: "课程简称与中午/傍晚时段", normalUserAvailable: false, passUserAvailable: true),
            ComparisonRow(title: "课程提醒", normalUserAvailable: false, passUserAvailable: true),
            ComparisonRow(title: "桌面/锁屏小组件", normalUserAvailable: false, passUserAvailable: true),
            ComparisonRow(title: "后续iOS版本专属功能", normalUserAvailable: false, passUserAvailable: true),
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
                .environmentObject(IAPStore.preview(hasActiveSubscription: false))
        }
    }
}
