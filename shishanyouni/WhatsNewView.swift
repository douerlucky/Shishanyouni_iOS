import SwiftUI

struct WhatsNewView: View
{
    let onDismiss: () -> Void

    private let features: [WhatsNewFeature] = [
        WhatsNewFeature(
            title: "校园通行证上线",
            message: "解锁桌面小组件、ITC 平台查询、GPA 分析、学期课程分析和个人日程等高级功能。",
            icon: "checkmark.seal.fill",
            color: .orange
        ),
        WhatsNewFeature(
            title: "桌面小组件正式上线",
            message: "通行证用户可以在桌面直接查看课程安排，不打开 App 也能快速掌握下一节课。",
            icon: "rectangle.on.rectangle.angled",
            color: .cyan
        ),
        WhatsNewFeature(
            title: "信息学院 ITC 平台查询",
            message: "支持查看作业截止时间、提交状态和最终得分；暂不支持提交作业。",
            icon: "chevron.left.forwardslash.chevron.right",
            color: .green
        ),
        WhatsNewFeature(
            title: "首页焕然一新",
            message: "首页 UI 全面重做，功能卡片可以自由移动、隐藏和整理，并新增 3 日内「下一个安排」。",
            icon: "house.and.flag.fill",
            color: .blue
        ),
        WhatsNewFeature(
            title: "日程与校历统一管理",
            message: "「校历查询」升级为「日程」：免费用户可看校历事件，通行证用户可管理待办、行程和备忘。",
            icon: "calendar.badge.clock",
            color: .purple
        ),
        WhatsNewFeature(
            title: "个性化背景加强",
            message: "首页、日程和课表现在都能分别启用自定义背景，并跟随透明度与玻璃效果设置。",
            icon: "photo.on.rectangle.angled",
            color: .mint
        ),
        WhatsNewFeature(
            title: "体验细节增强",
            message: "截止时间会显示今天、明天、3 天后或已过期；近期筛选更快，7 个查询模块的错误弹窗新增重试按钮。",
            icon: "wand.and.stars",
            color: .pink
        ),
    ]

    var body: some View
    {
        VStack(spacing: 24)
        {
            ScrollView(showsIndicators: false)
            {
                VStack(spacing: 24)
                {
                    VStack(spacing: 10)
                    {
                        Image(systemName: "party.popper.fill")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.pink, .orange, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("狮山有你iOS更新啦")
                            .font(.system(size: 28, weight: .black, design: .rounded))

                        Text("正式上线以来的最大的一次更新")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    VStack(spacing: 14)
                    {
                        ForEach(features)
                        { feature in
                            WhatsNewFeatureRow(feature: feature)
                        }
                    }
                }
            }

            Button(action: onDismiss)
            {
                Text("开始使用")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(
            ZStack
            {
                Color(uiColor: .systemBackground)

                Circle()
                    .fill(Color.blue.opacity(0.16))
                    .frame(width: 220, height: 220)
                    .blur(radius: 40)
                    .offset(x: -150, y: -220)

                Circle()
                    .fill(Color.pink.opacity(0.14))
                    .frame(width: 260, height: 260)
                    .blur(radius: 44)
                    .offset(x: 160, y: 230)
            }
                .ignoresSafeArea()
        )
    }
}

private struct WhatsNewFeatureRow: View
{
    let feature: WhatsNewFeature

    var body: some View
    {
        HStack(spacing: 14)
        {
            Image(systemName: feature.icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(feature.color)
                .frame(width: 48, height: 48)
                .background(feature.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 4)
            {
                Text(feature.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(feature.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
    }
}

private struct WhatsNewFeature: Identifiable
{
    let id = UUID()
    let title: String
    let message: String
    let icon: String
    let color: Color
}

#Preview
{
    WhatsNewView {}
}
