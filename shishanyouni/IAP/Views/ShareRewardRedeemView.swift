import StoreKit
import SwiftUI
import UIKit
import WebKit

struct ShareRewardRedeemView: View
{
    @State private var groupCopyMessage: String?
    @State private var offerCodeMessage: String?

    private var themePrimary: Color
    {
        Color(red: 23 / 255, green: 144 / 255, blue: 204 / 255)
    }

    var body: some View
    {
        ScrollView
        {
            VStack(alignment: .leading, spacing: 20)
            {
                VStack(alignment: .leading, spacing: 10)
                {
                    Text("分享应用领取兑换码")
                        .font(.system(size: 28, weight: .bold, design: .rounded))

                    Text("如果你觉得狮山有你 iOS 好用，可以把它分享给更多同学，审核通过后免费领取 3 个月校园通行证兑换码。")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(.ultraThinMaterial)
                )

                redeemContentCard
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
        .navigationTitle("免费领取兑换码")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var redeemContentCard: some View
    {
        VStack(alignment: .leading, spacing: 14)
        {
            Text("活动规则")
                .font(.title3.bold())

            Text("在任意公开社交平台发布 1 张 App 使用截图，并带上 #狮山有你 #狮山有你iOS 两个话题。发布后进入反馈群提交截图与链接，审核通过后可获得 3 个月校园通行证兑换码。")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .lineSpacing(4)

            VStack(alignment: .leading, spacing: 6)
            {
                HStack(alignment: .top, spacing: 6) { Text("•").foregroundColor(themePrimary); Text("要求「公开可见」").font(.system(size: 12)).foregroundColor(.secondary) }
                HStack(alignment: .top, spacing: 6) { Text("•").foregroundColor(themePrimary); Text("「截图 + 两个话题标签」").font(.system(size: 12)).foregroundColor(.secondary) }
                HStack(alignment: .top, spacing: 6) { Text("•").foregroundColor(themePrimary); Text("每个账号限领一次").font(.system(size: 12)).foregroundColor(.secondary) }
                HStack(alignment: .top, spacing: 6) { Text("•").foregroundColor(themePrimary); Text("兑换的是 Apple App Store 优惠码，兑换成功后会直接绑定到当前 Apple 账号的订阅权益").font(.system(size: 12)).foregroundColor(.secondary) }
                HStack(alignment: .top, spacing: 6) { Text("•").foregroundColor(themePrimary); Text("3 个月优惠结束后，将按 Apple 显示的订阅规则自动续订，可随时在系统订阅中取消").font(.system(size: 12)).foregroundColor(.secondary) }
            }

            HStack(spacing: 10)
            {
                HStack(spacing: 6)
                {
                    Image(systemName: "message.fill")
                        .font(.system(size: 14))
                        .foregroundColor(themePrimary)

                    Text("反馈群号：1090311516")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(themePrimary)
                }

                Spacer(minLength: 8)

                Button("复制群号")
                {
                    UIPasteboard.general.string = "1090311516"
                    groupCopyMessage = "已复制反馈群号"
                }
                .font(.system(size: 12, weight: .semibold))
                .nativeGlassButtonStyle()
                .tint(themePrimary)
            }
            .padding(10)
            .padding(.horizontal, 6)
            .background(themePrimary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

            if let groupCopyMessage
            {
                Text(groupCopyMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10)
            {
                Text("兑换优惠码")
                    .font(.system(size: 15, weight: .semibold))

                Button
                {
                    offerCodeMessage = "已打开 Apple 系统兑换窗口，请在系统弹窗中输入优惠码。"
                    SKPaymentQueue.default().presentCodeRedemptionSheet()
                }
                label:
                {
                    HStack(spacing: 8)
                    {
                        Image(systemName: "appstore")
                            .font(.system(size: 15, weight: .semibold))

                        Text("兑换优惠码")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .nativeGlassButtonStyle(prominent: true, fillsWidth: true, backgroundTint: themePrimary)
                .tint(themePrimary)
                .controlSize(.large)

                if let offerCodeMessage
                {
                    Text(offerCodeMessage)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

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
}
