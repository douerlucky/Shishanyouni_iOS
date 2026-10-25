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
        VStack(spacing: 14)
        {
            let iconShape = RoundedRectangle(cornerRadius: 22, style: .continuous)
            Image(systemName: scope.systemImage)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(scope.tint)
                .frame(width: 76, height: 76)
                .background(scope.tint.opacity(0.12), in: iconShape)
                .optionalLiquidGlass(in: iconShape)
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

            // 三个操作项统一放在说明文字下方：先“下次不再提醒”，再是取消/同意按钮组。
            VStack(spacing: 14)
            {
                Button
                {
                    rememberAuthorization.toggle()
                }
                label:
                {
                    HStack(spacing: 8)
                    {
                        Image(systemName: rememberAuthorization ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(rememberAuthorization ? .blue : .secondary)
                        Text("下次不再提醒")
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .center)

                HStack(spacing: 12)
                {
                    CancelButton
                    {
                        dismiss()
                    }

                    AcceptButton("我已阅读并同意授权")
                    {
                        onAuthorize(rememberAuthorization)
                        dismiss()
                    }
                }
                .frame(height: 48)
            }
            .padding(.top, 32)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .environment(\.isInsideLiquidGlassSurface, false)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("featureAuthorizationSheet")
    }
}
