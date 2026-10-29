import SwiftUI

/// 首次启动和功能授权 Sheet 共用同一份声明；修改内容时递增 revision。
enum AppUsageDisclaimer
{
    static let revision = "1"
    static let title = "使用声明"
    static let text = "本App不属于学校官方应用，一切信息请以学校官方网站为准。由于使用本App造成的任何损失，学校、开发者不负任何责任"
}

/// 未同意声明时不创建主界面，避免在选择之前启动各页面的数据查询。
struct AppDisclaimerWelcomeView: View
{
    let onAgree: () -> Void
    @State private var showDisclaimer = true
    @State private var hasDeclined = false

    var body: some View
    {
        VStack(spacing: 20)
        {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("狮山有你")
                .font(.title.bold())

            Text(hasDeclined
                 ? "你尚未同意使用声明，无法继续使用本应用。请返回主屏幕关闭应用，或重新查看声明。"
                 : "继续使用前，请阅读并同意使用声明。")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("disclaimerWelcomeMessage")

            Button("重新查看声明")
            {
                showDisclaimer = true
            }
            .nativeGlassButtonStyle(prominent: true)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
        .alert(AppUsageDisclaimer.title, isPresented: $showDisclaimer)
        {
            Button("同意，继续", action: onAgree)
            Button("不同意", role: .cancel)
            {
                // iOS 不提供正常退出应用的 API；拒绝后停留在入口页，由用户关闭。
                hasDeclined = true
            }
        } message: {
            Text(AppUsageDisclaimer.text)
        }
    }
}

