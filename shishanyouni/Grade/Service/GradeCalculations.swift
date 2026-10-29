import SwiftUI
import UIKit

/// 教务系统使用的学期值与 UI 不同：第一学期为 3，第二学期为 12。
/// “全学年”不能传 0，必须分别查询两个学期再合并。
func teachingSystemTerms(for selectedTerm: String) -> [String]
{
    switch selectedTerm
    {
    case "1": return ["3"]
    case "2": return ["12"]
    default: return ["3", "12"]
    }
}

// MARK: - GPA 计算 & 颜色

/// 根据百分制成绩计算绩点（按学校标准）
func computeGPA(from scoreStr: String) -> Double
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
    // 非数字等级（优秀/良好/合格/通过 等）
    switch scoreStr
    {
    case "优秀":       return 4.00
    case "良好":       return 3.00
    case "中等":       return 2.00
    case "合格", "通过": return 1.00
    default:          return 0.00
    }
}

/// 根据百分制成绩计算平均分（非数字返回 nil）
func computeScore(from scoreStr: String) -> Double?
{
    Double(scoreStr)
}

/// 根据绩点返回主题色
func gpaColor(_ gpa: Double) -> Color
{
    if gpa >= 4.00 { return .green }
    if gpa >= 3.00 { return .blue }
    if gpa >= 1.00 { return .orange }
    return .red
}

/// 汇总绩点颜色（按大众分布放宽标准）
func summaryGpaColor(_ gpa: Double) -> Color
{
    if gpa >= 3.70 { return .green }
    if gpa >= 3.30 { return .blue }
    if gpa >= 2.70 { return .orange }
    return .red
}
