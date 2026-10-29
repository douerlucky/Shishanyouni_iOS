import SwiftUI
import UIKit

// MARK: - 绩点圆环

struct GPARing: View {
    let gpa: Double
    let color: Color
    var centerText: String? = nil
    var isSummary: Bool = false

    private var progress: Double { min(gpa / 4.0, 1.0) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: 9)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: gpa)

            VStack(spacing: 4) {
                Text(centerText ?? String(format: "%.2f", gpa))
                    .font(.system(size: isSummary ? 24 : 20, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                if isSummary {
                    Text("平均学分绩点")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(color.opacity(0.7))
                }
            }
        }
    }
}

// MARK: - 单门课程卡片

struct GradeCard: View
{
    let grade: Grade
    /// 是否计入绩点统计
    @Binding var included: Bool
    /// 只有教务系统数据源才有可用的成绩明细接口。
    var showsDetailEntry = false
    /// 成绩明细属于校园通行证功能，未开通时显示锁定提示。
    var isDetailLocked = false
    var onShowDetail: (() -> Void)? = nil

    private var gpa: Double   { Double(grade.jd) ?? computeGPA(from: grade.cj) }
    private var color: Color  { included ? gpaColor(gpa) : .gray }

    var body: some View
    {
        // 整张卡片是一个明确的 Button，右上角勾选框是独立 Button。
        // 这样不会再依赖 ScrollView / LazyVGrid 中容易被竞争掉的 onTapGesture。
        ZStack(alignment: .topTrailing)
        {
            Button(action: { onShowDetail?() })
            {
                cardContent
            }
            .buttonStyle(.plain)
            .allowsHitTesting(showsDetailEntry)

            // 勾选状态只影响绩点统计，不会触发成绩明细弹窗。
            Button(action: { included.toggle() })
            {
                Image(systemName: included ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .nativeGlassButtonStyle(prominent: included, shape: .circle, fillsWidth: true, backgroundTint: included ? gpaColor(gpa) : nil)
            .tint(included ? gpaColor(gpa) : .gray)
            .controlSize(.mini)
            .frame(width: 32, height: 32)
            .accessibilityLabel(included ? "不计入绩点统计" : "计入绩点统计")
            .padding(16)
        }
        .animation(.easeInOut(duration: 0.2), value: included)
    }

    private var cardContent: some View
    {
        VStack(alignment: .leading, spacing: 10)
        {
            Text(grade.kcmc)
                .font(.system(size: 14))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, 28)
                .frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)

            // 绩点圆环（居中）
            HStack
            {
                Spacer()
                GPARing(gpa: included ? gpa : 0, color: color)
                    .frame(width: 64, height: 64)
                Spacer()
            }

            // 成绩（左）+ 学分（右）
            HStack
            {
                VStack(spacing: 2)
                {
                    Text(grade.cj)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                    Text("成绩")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(spacing: 2)
                {
                    Text(grade.xf)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(included ? .primary : .secondary)
                    Text("学分")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 6)

            if showsDetailEntry
            {
                HStack(spacing: 5)
                {
                    Image(systemName: isDetailLocked ? "lock.fill" : "list.bullet.rectangle")
                    Text("成绩明细")
                    Spacer()
                    if isDetailLocked
                    {
                        Text("通行证")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isDetailLocked ? .secondary : .blue)
                .padding(.top, 2)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .contentShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - 顶部汇总卡片

struct GradeSummaryCard: View
{
    /// 仅传入已勾选的课程
    let includedGrades: [Grade]
    /// 全部课程（用于计算平均分）
    let allGrades: [Grade]

    // 计入统计的（绩点）
    private var validGrades: [(gpa: Double, xf: Double)]
    {
        includedGrades.compactMap
        { g in
            let gpa = Double(g.jd) ?? computeGPA(from: g.cj)
            guard let xf = Double(g.xf) else { return nil }
            return (gpa, xf)
        }
    }

    /// 加权平均绩点 = Σ(学分×绩点) / Σ学分
    private var weightedGPA: Double
    {
        let totalXF  = validGrades.reduce(0.0) { $0 + $1.xf }
        let weighted = validGrades.reduce(0.0) { $0 + $1.gpa * $1.xf }
        guard totalXF > 0 else { return 0 }
        return weighted / totalXF
    }

    /// 算术平均分（仅数字成绩）
    private var averageScore: Double?
    {
        let scores = includedGrades.compactMap { computeScore(from: $0.cj) }
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / Double(scores.count)
    }

    /// 加权平均分 = Σ(学分×分数) / Σ学分
    private var weightedScore: Double?
    {
        let pairs = includedGrades.compactMap { g -> (Double, Double)? in
            guard let score = computeScore(from: g.cj),
                  let xf = Double(g.xf) else { return nil }
            return (score, xf)
        }
        guard !pairs.isEmpty else { return nil }
        let totalXF = pairs.reduce(0.0) { $0 + $1.1 }
        guard totalXF > 0 else { return nil }
        return pairs.reduce(0.0) { $0 + $1.0 * $1.1 } / totalXF
    }

    private var totalCredits: Double
    {
        validGrades.reduce(0.0) { $0 + $1.xf }
    }

    private var color: Color { summaryGpaColor(weightedGPA) }

    var body: some View
    {
        VStack(spacing: 16)
        {
            // 大圆：加权平均绩点
            GPARing(gpa: weightedGPA, color: color, isSummary: true)
                .frame(width: 120, height: 120)

            // 统计数据行
            HStack(spacing: 0)
            {
                // 平均分
                VStack(spacing: 4)
                {
                    if let avg = averageScore
                    {
                        Text(String(format: "%.2f", avg))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    else
                    {
                        Text("—")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    Text("平均分")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                // 分割线
                Divider()
                    .frame(height: 36)

                // 加权平均分
                VStack(spacing: 4)
                {
                    if let ws = weightedScore
                    {
                        Text(String(format: "%.2f", ws))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    else
                    {
                        Text("—")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    Text("加权平均分")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                // 分割线
                Divider()
                    .frame(height: 36)

                // 记录课程数 / 总学分
                VStack(spacing: 4)
                {
                    Text("\(includedGrades.count) 门")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("记录课程")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                // 分割线
                Divider()
                    .frame(height: 36)

                // 总学分
                VStack(spacing: 4)
                {
                    Text(String(format: "%.1f", totalCredits))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("总学分")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal, 16)
    }
}

#Preview
{
    GradeInquiry()
        .environmentObject(userInfo())
        .environmentObject(IAPStore.preview(hasActiveSubscription: false))
}
