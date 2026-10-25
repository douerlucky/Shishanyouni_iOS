import SwiftUI

struct WhatsNewView: View
{
    let onDismiss: () -> Void

    private let features: [WhatsNewFeature] = [
        WhatsNewFeature(
            title: "课表导入与课程管理",
            message: "课表支持从\(SchoolServiceName.academicPlatform)导入，“所有课程”可查看未显示在课表中的实践课程及其他课程。",
            icon: "calendar.badge.plus",
            color: .orange
        ),
        WhatsNewFeature(
            title: "首页UI交互优化",
            message: "重构首页UI,首页上滑呼出全部功能更丝滑，全部功能现按照分类来进行归类，使用功能更加方便。",
            icon: "rectangle.roundedtop.fill",
            color: .cyan
        ),
        WhatsNewFeature(
            title: "查询前授权说明",
            message: "进入成绩、考试、体测、选课等账号功能前，会明确说明数据是通过狮山有你接口还是直接访问学校系统查询；可选择下次不再提醒。",
            icon: "checkmark.shield.fill",
            color: .blue
        ),
        WhatsNewFeature(
            title: "UI统一、交互优化",
            message: "在日程和校历的日历卡片上左右滑动，即可切换上一周或下一周，并带有轻微触感反馈。",
            icon: "hand.draw.fill",
            color: .purple
        ),
        WhatsNewFeature(
            title: "空教室查询周次快捷栏",
            message: "空教室查询底部常驻显示第几周和星期；单箭头切换前后一天，双箭头切换前后整周。",
            icon: "calendar.badge.clock",
            color: .green
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

                        Text("狮山有你更新啦")
                            .font(.system(size: 28, weight: .black, design: .rounded))

                        Text("首页、授权说明、日程与空教室查询体验优化")
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
                    .optionalLiquidGlass(allowsNesting: true, in: Capsule())
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
            if let originalName = feature.previewOriginalName,
               let shortName = feature.previewShortName
            {
                CourseAbbreviationIcon(
                    originalName: originalName,
                    shortName: shortName,
                    color: feature.color
                )
            }
            else
            {
                let iconShape = RoundedRectangle(cornerRadius: 16, style: .continuous)
                Image(systemName: feature.icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(feature.color)
                    .frame(width: 48, height: 48)
                    .background(feature.color.opacity(0.14), in: iconShape)
            }

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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .optionalLiquidGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// “课程简称”功能的图示：完整课程名向下转换为简称。
private struct CourseAbbreviationIcon: View
{
    let originalName: String
    let shortName: String
    let color: Color

    var body: some View
    {
        VStack(spacing: 0)
        {
            Text(originalName)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Image(systemName: "arrow.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)

            Text(shortName)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
        }
        .frame(width: 64, height: 56)
        .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct WhatsNewFeature: Identifiable
{
    let id = UUID()
    let title: String
    let message: String
    let icon: String
    let color: Color
    let previewOriginalName: String?
    let previewShortName: String?

    init(
        title: String,
        message: String,
        icon: String,
        color: Color,
        previewOriginalName: String? = nil,
        previewShortName: String? = nil
    )
    {
        self.title = title
        self.message = message
        self.icon = icon
        self.color = color
        self.previewOriginalName = previewOriginalName
        self.previewShortName = previewShortName
    }
}

#Preview
{
    WhatsNewView {}
}
