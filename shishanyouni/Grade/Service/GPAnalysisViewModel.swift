import SwiftUI
import Charts

// MARK: - ViewModel

@MainActor
class GPAnalysisViewModel: ObservableObject
{
    @Published var semesters: [SemesterSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let gradeService = ShishanyouniGradeService()
    func fetchAllSemesters(username: String, encryptedPassword: String, mfa: ShishanyouniV3MFAProvider?) async
    {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        var results: [SemesterSummary] = []

        do
        {
            // V3 按已开始的学期汇总，所有请求复用门户凭据与教务子会话。
            let allGrades = try await gradeService.fetchGrades(
                username: username,
                encryptedPassword: encryptedPassword,
                year: "",
                term: "0",
                mfa: mfa
            )

            let grouped = Dictionary(grouping: allGrades) { grade in
                "\(grade.xnm ?? grade.xnmmc ?? "未知学年")|\(grade.xqm ?? grade.xqmmc ?? "0")"
            }
            for grades in grouped.values
            {
                guard let first = grades.first,
                      let academicYear = first.xnm ?? first.xnmmc,
                      let startYear = academicYear.split(separator: "-").first,
                      let termCode = first.xqm ?? first.xqmmc
                else { continue }
                let termName = termCode == "1" ? "一" : termCode == "2" ? "二" : termCode
                if let summary = buildSummary(grades, year: String(startYear), termName: termName)
                {
                    results.append(summary)
                }
            }
        }
        catch
        {
            errorMessage = error.localizedDescription
        }

        semesters = results.sorted { a, b in a.semester < b.semester }

        if semesters.isEmpty && errorMessage == nil
        {
            errorMessage = "未查询到任何学期成绩，请先在成绩查询中获取数据。"
        }

        isLoading = false
    }

    private func buildSummary(_ grades: [Grade], year: String, termName: String) -> SemesterSummary?
    {
        let gpaValues = grades.compactMap { g -> (Double, Double, Double?)? in
            let gpa = gradeAnalysisComputeGPA(from: g.cj)
            let credits = Double(g.xf) ?? 0
            let score = scoreFrom(g.cj)
            return (gpa, credits, score)
        }

        guard !gpaValues.isEmpty else { return nil }

        let totalCredits = gpaValues.reduce(0) { acc, val in acc + val.1 }
        let weightedGPA = totalCredits > 0
            ? gpaValues.reduce(0) { acc, val in acc + val.0 * val.1 } / totalCredits
            : 0

        let numericScores = gpaValues.compactMap { $0.2 }
        let avgScore = numericScores.isEmpty ? 0
            : numericScores.reduce(0, +) / Double(numericScores.count)

        let yearEnd = (Int(year) ?? 0) + 1
        let yearSuffix = (yearEnd) % 100
        let yearPrefix = (Int(year) ?? 0) % 100
        let semesterLabel = String(format: "%02d-%02d 第%@学期", yearPrefix, yearSuffix, termName)

        return SemesterSummary(
            semester: "\(year)\(termName)",
            termLabel: semesterLabel,
            gpa: weightedGPA,
            avgScore: avgScore,
            totalCredits: totalCredits,
            courseCount: grades.count,
            grades: grades
        )
    }

    var overallGPA: Double
    {
        guard !semesters.isEmpty else { return 0 }
        let total = semesters.reduce(0) { $0 + $1.gpa * $1.totalCredits }
        let totalC = semesters.reduce(0) { $0 + $1.totalCredits }
        return totalC > 0 ? total / totalC : 0
    }

    var overallCredits: Double
    {
        semesters.reduce(0) { $0 + $1.totalCredits }
    }

    var overallCourses: Int
    {
        semesters.reduce(0) { $0 + $1.courseCount }
    }
}
