import SwiftUI

let physicalTestReferenceTitle = "《国家学生体质健康标准（2014年修订）》"
let physicalTestReferenceURL = URL(string: "http://www.moe.gov.cn/s78/A17/twys_left/moe_938/moe_792/s3273/201407/t20140708_171692.html")!
let physicalTestSectionSpacing: CGFloat = 20
let physicalTestCardHorizontalPadding: CGFloat = 16
let physicalTestCardInnerPadding: CGFloat = 16

func getScoreColor(score: Double) -> Color
{
    switch score
    {
    case ..<60: return .red
    case 60 ..< 80: return .orange
    case 80 ..< 90: return .blue
    default: return .green
    }
}

struct MainScoreRing: View
{
    let score: Double
    let totalGrade: String
    var body: some View
    {
        ZStack
        {
            Circle()
                .stroke(getScoreColor(score: score).opacity(0.1), lineWidth: 15)
            Circle()
                .trim(from: 0, to: CGFloat(score / 100.0))
                .stroke(
                    getScoreColor(score: score),
                    style: StrokeStyle(lineWidth: 15, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: getScoreColor(score: score).opacity(0.3), radius: 5)

            VStack(spacing: 4)
            {
                Text(String(format: "%.1f", score))
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(getScoreColor(score: score))
                Text(totalGrade)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(getScoreColor(score: score))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                    .background(
                        getScoreColor(score: score).opacity(0.15)
                    )
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - 单项数据卡片

struct DetailCard: View
{
    let detail: PhysicalDetail

    var body: some View
    {
        VStack(alignment: .leading, spacing: 12)
        {
            Text(detail.project)
                .font(.system(size: 16))
                .foregroundColor(.secondary)

            HStack
            {
                Spacer()
                MiniScoreBadge(score: Double(detail.score) ?? 0)
                Spacer()
            }

            HStack
            {
                Text(detail.result)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                Text(detail.grade)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(gradeColor(detail.grade))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                    .background(
                        gradeColor(detail.grade).opacity(0.15)
                    )
                    .clipShape(Capsule())
            }
        }
        .padding(physicalTestCardInnerPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }

    private func gradeColor(_ grade: String) -> Color
    {
        if grade.contains("不") { return .red }
        if grade.contains("及格") { return .orange }
        return .green
    }
}

struct BMIDetailRow: View
{
    let detail: PhysicalDetail

    private var scoreValue: Double
    {
        Double(detail.score) ?? 0
    }

    private func gradeColor(_ grade: String) -> Color
    {
        if grade.contains("不") { return .red }
        if grade.contains("及格") || grade.contains("超重") { return .orange }
        return .green
    }

    var body: some View
    {
        HStack(alignment: .top, spacing: 20)
        {
            VStack(spacing: 14)
            {
                Text(detail.project)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack
                {
                    Spacer()
                    MiniScoreBadge(score: scoreValue)
                    Spacer()
                }

                HStack
                {
                    Text(detail.result)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Spacer()

                    Text(detail.grade)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(gradeColor(detail.grade))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                        .background(gradeColor(detail.grade).opacity(0.15))
                        .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            VStack(alignment: .leading, spacing: 4)
            {
                Text("BMI 信息依据：\(physicalTestReferenceTitle)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Link("查看 BMI 官方标准说明", destination: physicalTestReferenceURL)
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(minHeight: 168)
        .padding(physicalTestCardInnerPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
}

struct MiniScoreBadge: View
{
    let score: Double

    var body: some View
    {
        ZStack
        {
            // 底色细环
            Circle()
                .stroke(getScoreColor(score: score).opacity(0.1), lineWidth: 8)

            // 进度细环
            Circle()
                .trim(from: 0, to: CGFloat(score / 100.0))
                .stroke(
                    getScoreColor(score: score),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // 中间的文字，把之前的样式缩写进去
            Text(String(format: "%.0f", score))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(getScoreColor(score: score))
        }
        .frame(width: 64, height: 64) // 控制整体大小，28px 左右非常精致
        .padding(4)
    }
}

struct PhysicalTestQueryButton: View
{
    @Binding var selectedYear: String
    @Binding var showPicker: Bool

    var fetchPhysicalData: () -> Void

    var body: some View
    {
        HStack(spacing: 20)
        {
            SemesterSelector(title: selectedYear, action: { showPicker = true })
            AcceptButton("同步成绩", action: fetchPhysicalData)
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
    PhysicalTestView().environmentObject(userInfo())
}
