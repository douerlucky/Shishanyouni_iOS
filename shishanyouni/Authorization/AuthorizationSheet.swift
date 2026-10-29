import SwiftUI

/// 查询校园数据前展示的统一授权说明。
struct FeatureAuthorizationSheet: View
{
    let scope: FeatureAuthorizationScope
    let onAuthorize: (_ remember: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var rememberAuthorization = false

    var body: some View
    {
        ScrollView
        {
            authorizationDetails
        }
        .safeAreaInset(edge: .bottom)
        {
            HStack(spacing: 12)
            {
                CancelButton { dismiss() }
                AcceptButton("我已阅读并同意授权")
                {
                    onAuthorize(rememberAuthorization)
                    dismiss()
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
        }
        .environment(\.isInsideLiquidGlassSurface, false)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("featureAuthorizationSheet")
    }

    private var authorizationDetails: some View
    {
        VStack(spacing: 14)
        {
            let iconShape = RoundedRectangle(cornerRadius: 22, style: .continuous)
            Image(systemName: scope.systemImage)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(scope.tint)
                .frame(width: 76, height: 76)
                .optionalLiquidGlass(in: iconShape, fallback: scope.tint.opacity(0.12))
                .padding(.top, 12)

            VStack(spacing: 4)
            {
                Text(scope.displayName)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("授权使用你的账号信息进行查询")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)

            Label(scope.sourceDescription, systemImage: "arrow.triangle.branch")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)

            Text(AppUsageDisclaimer.text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)

            Toggle("下次不再提醒", isOn: $rememberAuthorization)
                .tint(appActionBlue)
                .padding(.top, 16)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
    }
}
