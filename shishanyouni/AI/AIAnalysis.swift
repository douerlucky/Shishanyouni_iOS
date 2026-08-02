//
//  AIAnalysis.swift
//  shishanyouni
//
//  AI 智学助手（beta）数据分析层：
//  从本地缓存（GradeStore / CurriculumStore）收集成绩、课程数据，
//  并生成绩点分析与课程分析所需的提示词。
//

import Foundation

// MARK: - GPA 计算（与 Grade/GPAnalysisView 保持一致，文件独立）

private func aiComputeGPA(from scoreStr: String) -> Double
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

// MARK: - 学期成绩汇总

struct AISemesterGradeData
{
    let semesterLabel: String
    let gpa: Double
    let totalCredits: Double
    let grades: [Grade]
}

enum AIAnalysis
{
    // MARK: - 数据收集

    /// 从 GradeStore 缓存读取全部学期成绩（与成绩查询页面缓存一致）
    static func collectGradeData(username: String) -> [AISemesterGradeData]
    {
        let years = ["2022", "2023", "2024", "2025"]
        let terms: [(String, String)] = [("1", "一"), ("2", "二")]

        var results: [AISemesterGradeData] = []

        for year in years
        {
            for (termCode, termName) in terms
            {
                let grades = GradeStore.shared.loadGrades(username: username, year: year, term: termCode)
                guard !grades.isEmpty else { continue }

                var weighted = 0.0
                var totalCredits = 0.0
                for g in grades
                {
                    let gpa = aiComputeGPA(from: g.cj)
                    let credits = Double(g.xf) ?? 0
                    weighted += gpa * credits
                    totalCredits += credits
                }
                guard totalCredits > 0 else { continue }

                let yearEnd = (Int(year) ?? 0) + 1
                let label = String(format: "%02d-%02d 第%@学期", (Int(year) ?? 0) % 100, yearEnd % 100, termName)

                results.append(AISemesterGradeData(
                    semesterLabel: label,
                    gpa: weighted / totalCredits,
                    totalCredits: totalCredits,
                    grades: grades
                ))
            }
        }

        return results.sorted { a, b in a.semesterLabel < b.semesterLabel }
    }

    /// 从课表缓存读取课程
    static func collectCourseData() -> [Course]
    {
        CurriculumStore.shared.loadCourses()
    }

    // MARK: - 绩点分析提示词

    static func buildGPAAnalysisPrompt(semesters: [AISemesterGradeData], username: String) -> String
    {
        var lines: [String] = []
        lines.append("以下是一名华中农业大学学生（学号 \(username)）的成绩数据，请进行绩点与学业分析。")
        lines.append("要求：用简洁中文回答，3-5 个自然段。先给出整体绩点评定，再分析趋势与薄弱科目，最后给出可执行的提升建议。")

        for semester in semesters
        {
            lines.append("\n【\(semester.semesterLabel)】")
            lines.append("学期绩点：\(String(format: "%.2f", semester.gpa))，总学分：\(String(format: "%.1f", semester.totalCredits))")
            for g in semester.grades
            {
                let name = g.kcmc.isEmpty ? "未知课程" : g.kcmc
                let category = g.kcxzmc?.isEmpty == false ? g.kcxzmc! : "未分类"
                let credits = Double(g.xf) ?? 0
                lines.append("  - \(name)（\(category)，\(String(format: "%.1f", credits)) 学分）：成绩 \(g.cj)")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - 课程分析提示词

    static func buildCourseAnalysisPrompt(courses: [Course], semesters: [AISemesterGradeData], username: String) -> String
    {
        var lines: [String] = []
        lines.append("以下是一名华中农业大学学生（学号 \(username)）的本学期课表与历史成绩，请进行课程学习分析。")
        lines.append("要求：用简洁中文回答，3-5 个自然段。先按课程性质（必修/选修）梳理当前课程，再结合历史成绩给出学习重点与时间安排建议。")

        if !courses.isEmpty
        {
            lines.append("\n【当前课表课程】")
            for course in courses
            {
                var info = "  - \(course.name)"
                if let teacher = course.teacher, !teacher.isEmpty { info += "（\(teacher)）" }
                if let room = course.room, !room.isEmpty { info += " \(room)" }
                info += "，每周第 \(course.start)-\(course.start + course.step - 1) 节，周\(course.day)"
                if let weeks = course.weeks, !weeks.isEmpty { info += "，\(weeks)" }
                lines.append(info)
            }
        }
        else
        {
            lines.append("\n【当前课表】未查询到课表数据，请提示用户先在课表页获取课程。")
        }

        if !semesters.isEmpty
        {
            lines.append("\n【历史成绩（仅列与当前课程相关的参考信息）】")
            for semester in semesters
            {
                lines.append("\(semester.semesterLabel)：学期绩点 \(String(format: "%.2f", semester.gpa))")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - 对话系统提示词

    static func buildChatSystemPrompt(semesters: [AISemesterGradeData]) -> String
    {
        var summary = "你是一名贴心的大学学业助手「智学小狮」，正在为华中农业大学的学生提供帮助。回答用中文，简洁清晰，适当给出鼓励。"

        guard !semesters.isEmpty else
        {
            return summary + "\n\n（用户尚未在成绩查询中获取成绩数据，可引导用户先去查询成绩。）"
        }

        let totalCredits = semesters.reduce(0) { $0 + $1.totalCredits }
        let overallGPA = semesters.reduce(0) { $0 + $1.gpa * $1.totalCredits } / totalCredits
        let totalCourses = semesters.reduce(0) { $0 + $1.grades.count }

        summary += "\n\n当前掌握的用户学业数据："
        summary += "\n- 总绩点：\(String(format: "%.2f", overallGPA))"
        summary += "\n- 总学分：\(String(format: "%.1f", totalCredits))"
        summary += "\n- 总课程数：\(totalCourses)"

        if let latest = semesters.last
        {
            summary += "\n- 最近学期（\(latest.semesterLabel)）：绩点 \(String(format: "%.2f", latest.gpa))，学分 \(String(format: "%.1f", latest.totalCredits))"
            let latestCourses = latest.grades.prefix(10).map { g in
                let name = g.kcmc.isEmpty ? "未知课程" : g.kcmc
                return "\(name)(\(g.cj))"
            }
            summary += "\n- 最近学期部分课程成绩：\(latestCourses.joined(separator: "、"))"
        }

        return summary
    }
}
