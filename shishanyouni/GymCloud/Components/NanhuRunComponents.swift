import SwiftUI

/// 环湖跑小卡片组件
struct RunScoreCard: View
{
    let score: RunScore

    var body: some View
    {
        VStack(alignment: .leading, spacing: 15)
        {
            // 左上角：学年 + 学期
            HStack
            {
                HStack(spacing: 4)
                {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                    Text("\(score.schoolYear)学年 第\(score.semester)学期")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)

                Spacer()
            }

            // 中间：圈数放大显示
            VStack(spacing: 5)
            {
                Text(score.count)
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundColor(.primary)

                Text("已跑圈数")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
}

/// 模糊背景组件
struct BlurView: UIViewRepresentable
{
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView
    {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

struct NanhuRunQueryButton: View
{
    @Binding var querySource: NanhuRunQuerySource
    var fetchNanhuRunData: () -> Void

    var body: some View
    {
        HStack(spacing: 20)
        {
            DataSourceSelector(
                selection: $querySource,
                fontSize: 15
            )

            AcceptButton("同步数据", action: fetchNanhuRunData)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .glassBackground(cornerRadius: 64)
        .padding(.horizontal, 20)
        .padding(.bottom, 30) // 距离底部安全区域的距离
    }
}

#Preview
{
    NavigationStack
    {
        NanhuRunView()
            .environmentObject(userInfo())
    }
}
