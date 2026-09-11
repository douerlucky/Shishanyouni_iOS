import SwiftUI

struct WhatsNewView: View
{
    let onDismiss: () -> Void

    private let features: [WhatsNewFeature] = [
        WhatsNewFeature(
            title: "期末考核类型",
            message: "所有课程现在都能查看期末考核是考试还是考查。",
            icon: "checkmark.seal.fill",
            color: .teal
        ),
        WhatsNewFeature(
            title: "成绩长图下载",
            message: "成绩查询现在支持一键下载长图。校园通行证用户专属。",
            icon: "arrow.down.doc.fill",
            color: .blue
        ),
        WhatsNewFeature(
            title: "全新小组件",
            message: "全新设计，现有大、中、小三种样式可选。校园通行证用户专属。",
            icon: "widget.large.badge.plus",
            color: .purple
        ),
        WhatsNewFeature(
            title: "锁屏下节课",
            message: "锁定屏幕也能添加小组件，显示下一节课。校园通行证用户专属。",
            icon: "lock.fill",
            color: .indigo
        ),
        WhatsNewFeature(
            title: "课程导入系统日历",
            message: "支持一键导入所有课程，也可一键删除；不会删除你自己创建的日程。校园通行证用户专属。",
            icon: "calendar.badge.plus",
            color: .orange
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

                        Text("课程、成绩、小组件与日历功能更新")
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
