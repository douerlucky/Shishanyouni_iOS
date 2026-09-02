import SwiftUI

struct WhatsNewView: View
{
    let onDismiss: () -> Void

    private let features: [WhatsNewFeature] = [
        WhatsNewFeature(
            title: "选课功能上线",
            message: "支持查看课程、教学班和子教学班，并直接提交选课。",
            icon: "list.bullet.clipboard.fill",
            color: .blue
        ),
        WhatsNewFeature(
            title: "校历更新",
            message: "校历活动从教务系统获取，已更新至 2026–2027 学年。",
            icon: "arrow.triangle.2.circlepath.circle.fill",
            color: .teal
        ),
        WhatsNewFeature(
            title: "课程查询更方便",
            message: "选课和全校课程查询支持系统搜索，滑到底部会自动加载更多课程。",
            icon: "magnifyingglass.circle.fill",
            color: .purple
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

                        Text("选课上线，校历与课程查询更新")
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
