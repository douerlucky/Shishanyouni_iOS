import SwiftUI
import Charts

// MARK: - GPA 与分数分布计算

func gradeAnalysisComputeGPA(from scoreStr: String) -> Double
{
    if let score = Double(scoreStr)
    {
        if score >= 90 { return 4.00 }
        if score >= 85 { return 3.70 }
        if score >= 82 { return 3.30 }
        if score >= 78 { return 3.00 }
        if score >= 75 { return 2.70 }
        if score >= 72 { return 2.30 }
        if score >= 68 { return 2.00 }
        if score >= 64 { return 1.50 }
        if score >= 60 { return 1.00 }
        return 0.00
    }
    switch scoreStr
    {
    case "优秀":       return 4.00
    case "良好":       return 3.00
    case "中等":       return 2.00
    case "合格", "通过": return 1.00
    default:          return 0.00
    }
}

func gradeAnalysisSummaryGpaColor(_ gpa: Double) -> Color
{
    if gpa >= 3.70 { return .green }
    if gpa >= 3.30 { return .blue }
    if gpa >= 2.70 { return .orange }
    return .red
}

func scoreFrom(_ cj: String) -> Double?
{
    Double(cj)
}

func buildScoreDistribution(_ grades: [Grade]) -> [ScoreDistItem]
{
    var buckets: [String: Int] = [
        "90-100 (A)": 0,
        "80-89 (B)": 0,
        "70-79 (C)": 0,
        "60-69 (D)": 0,
        "<60 (F)": 0,
    ]

    for g in grades
    {
        guard let score = Double(g.cj) else { continue }
        if score >= 90 { buckets["90-100 (A)"]! += 1 }
        else if score >= 80 { buckets["80-89 (B)"]! += 1 }
        else if score >= 70 { buckets["70-79 (C)"]! += 1 }
        else if score >= 60 { buckets["60-69 (D)"]! += 1 }
        else { buckets["<60 (F)"]! += 1 }
    }

    return buckets
        .map { ScoreDistItem(range: $0.key, count: $0.value) }
        .sorted { a, b in
            let order = ["90-100 (A)", "80-89 (B)", "70-79 (C)", "60-69 (D)", "<60 (F)"]
            return (order.firstIndex(of: a.range) ?? 0) < (order.firstIndex(of: b.range) ?? 0)
        }
}
