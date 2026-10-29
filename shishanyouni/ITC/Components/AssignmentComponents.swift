import SwiftUI

// MARK: - Assignment Card

struct AssignmentCard: View
{
    let assignment: ITC_Assignment

    var body: some View
    {
        VStack(alignment: .leading, spacing: 12)
        {
            // 作业标题
            Text(assignment.assignName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 截止时间（纯文字，无图标）
            if let ddl = assignment.ddlTime
            {
                Text("截止时间 \(ddl)")
                    .font(.system(size: 13))
                    .foregroundColor(ddlColor(ddl))
                    .lineLimit(1)
            }

            // 底部 Row：进度环（环内显示 X/X）+ 得分
            HStack(spacing: 16)
            {
                if assignment.totalQuestionCount > 0
                {
                    AssignmentProgressRing(
                        completed: assignment.completedCount,
                        total: assignment.totalQuestionCount
                    )
                }

                if assignment.finalScore != "-"
                {
                    HStack(spacing: 4)
                    {
                        Text("得分")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Text(assignment.finalScore)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                }

                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 3)
        )
        .padding(.bottom, 10)
    }

    private func ddlColor(_ ddl: String) -> Color
    {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let date = formatter.date(from: ddl) else { return .secondary }
        return date < Date() ? .red : .secondary
    }
}

// MARK: - 题目完成进度圆环（圆环 + 横排 X/X 文字）

private struct AssignmentProgressRing: View
{
    let completed: Int
    let total: Int

    private var progress: Double
    {
        total > 0 ? Double(completed) / Double(total) : 0
    }

    private var ringColor: Color
    {
        if completed == total { return .green }
        if completed == 0 { return .secondary }
        return .orange
    }

    var body: some View
    {
        // 圆环，X/X 显示在环内
        ZStack
        {
            Circle()
                .stroke(ringColor.opacity(0.15), lineWidth: 7)

            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(ringColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.4), value: progress)

            // 环内 X/X
            HStack(spacing: 1)
            {
                Text("\(completed)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text("/\(total)")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 52, height: 52)
    }
}

// MARK: - 得分 Pill

private struct ScorePill: View
{
    let score: String

    private var scoreDouble: Double { Double(score) ?? 0 }

    var body: some View
    {
        Text(score)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundColor(getScoreColor(score: scoreDouble))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(getScoreColor(score: scoreDouble).opacity(0.12))
            .clipShape(Capsule())
    }
}
