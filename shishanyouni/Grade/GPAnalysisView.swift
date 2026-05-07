import SwiftUI
import Charts

// MARK: - GPA Helpers (duplicated for file independence)

private func computeGPA(from scoreStr: String) -> Double
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

private func summaryGpaColor(_ gpa: Double) -> Color
{
    if gpa >= 3.70 { return .green }
    if gpa >= 3.30 { return .blue }
    if gpa >= 2.70 { return .orange }
    return .red
}

private func scoreFrom(_ cj: String) -> Double?
{
    Double(cj)
}

// MARK: - Semester Summary Data

struct SemesterSummary: Identifiable
{
    let id = UUID()
    let semester: String
    let termLabel: String
    let gpa: Double
    let avgScore: Double
    let totalCredits: Double
    let courseCount: Int
    let grades: [Grade]
}

// MARK: - ViewModel

@MainActor
class GPAnalysisViewModel: ObservableObject
{
    @Published var semesters: [SemesterSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let gradeService = GradeService()
    private let years = ["2022", "2023", "2024", "2025"]
    private let terms: [(String, String)] = [("1", "一"), ("2", "二")]

    func fetchAllSemesters(username: String, password: String) async
    {
        isLoading = true
        errorMessage = nil

        var results: [SemesterSummary] = []

        for year in years
        {
            for (termCode, termName) in terms
            {
                do
                {
                    let grades = try await gradeService.fetchGrades(
                        username: username,
                        password: password,
                        xnm: year,
                        xqm: termCode
                    )
                    if !grades.isEmpty, let summary = buildSummary(grades, year: year, termName: termName)
                    {
                        results.append(summary)
                    }
                }
                catch {}
            }
        }

        semesters = results.sorted { a, b in a.semester < b.semester }

        if semesters.isEmpty
        {
            errorMessage = "未查询到任何学期成绩，请先在成绩查询中获取数据。"
        }

        isLoading = false
    }

    private func buildSummary(_ grades: [Grade], year: String, termName: String) -> SemesterSummary?
    {
        let gpaValues = grades.compactMap { g -> (Double, Double, Double?)? in
            let gpa = computeGPA(from: g.cj)
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

// MARK: - GPA Analysis View

struct GPAnalysisView: View
{
    @EnvironmentObject var userinfo: userInfo
    @StateObject private var vm = GPAnalysisViewModel()

    var body: some View
    {
        Group
        {
            if vm.isLoading
            {
                VStack(spacing: 16)
                {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("正在分析成绩数据...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            else if let error = vm.errorMessage
            {
                VStack(spacing: 16)
                {
                    Image(systemName: "chart.line.downtrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("重试")
                    {
                        Task { await vm.fetchAllSemesters(
                            username: userinfo.username,
                            password: userinfo.encryptedPasswordShishanyouni
                        )}
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(32)
            }
            else
            {
                contentView
            }
        }
        .navigationTitle("GPA 分析")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .background(Color(uiColor: .systemGroupedBackground))
        .task {
            if vm.semesters.isEmpty
            {
                await vm.fetchAllSemesters(
                    username: userinfo.username,
                    password: userinfo.encryptedPasswordShishanyouni
                )
            }
        }
    }

    private var contentView: some View
    {
        ScrollView
        {
            VStack(spacing: 16)
            {
                overallSummaryCard
                gpaTrendChart
                creditPerSemesterChart
                scoreDistributionChart
            }
            .padding(.vertical)
        }
    }

    // MARK: - Overall Summary

    private var overallSummaryCard: some View
    {
        HStack(spacing: 0)
        {
            VStack(spacing: 4)
            {
                Text(String(format: "%.2f", vm.overallGPA))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(summaryGpaColor(vm.overallGPA))
                Text("总绩点")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 50)

            VStack(spacing: 4)
            {
                Text(String(format: "%.1f", vm.overallCredits))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)
                Text("总学分")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 50)

            VStack(spacing: 4)
            {
                Text("\(vm.overallCourses)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
                Text("总课程")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .padding(.horizontal)
    }

    // MARK: - GPA Trend Chart

    private var gpaTrendChart: some View
    {
        VStack(alignment: .leading, spacing: 12)
        {
            Label("绩点趋势", systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline)
                .padding(.horizontal)

            if vm.semesters.count < 2
            {
                Text("需要至少 2 个学期才可展示趋势图")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 30)
            }
            else
            {
                Chart(vm.semesters)
                { semester in
                    LineMark(
                        x: .value("学期", semester.termLabel),
                        y: .value("绩点", semester.gpa)
                    )
                    .foregroundStyle(.blue.gradient)
                    .lineStyle(StrokeStyle(lineWidth: 3))

                    PointMark(
                        x: .value("学期", semester.termLabel),
                        y: .value("绩点", semester.gpa)
                    )
                    .foregroundStyle(.blue)
                    .annotation(position: .top)
                    {
                        Text(String(format: "%.2f", semester.gpa))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }
                .chartYScale(domain: 0...4.0)
                .chartXAxis
                {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel()
                            .font(.system(size: 10))
                    }
                }
                .chartYAxis
                {
                    AxisMarks(values: [0, 1, 2, 3, 4])
                    {
                        AxisValueLabel()
                            .font(.system(size: 10))
                    }
                }
                .frame(height: 220)
                .padding(.horizontal, 8)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .padding(.horizontal)
    }

    // MARK: - Credits Per Semester

    private var creditPerSemesterChart: some View
    {
        VStack(alignment: .leading, spacing: 12)
        {
            Label("学期学分", systemImage: "chart.bar.fill")
                .font(.headline)
                .padding(.horizontal)

            Chart(vm.semesters)
            { semester in
                BarMark(
                    x: .value("学期", semester.termLabel),
                    y: .value("学分", semester.totalCredits)
                )
                .foregroundStyle(.orange.gradient)
                .annotation(position: .top)
                {
                    Text(String(format: "%.0f", semester.totalCredits))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .chartXAxis
            {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel()
                        .font(.system(size: 10))
                }
            }
            .frame(height: 180)
            .padding(.horizontal, 8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .padding(.horizontal)
    }

    // MARK: - Score Distribution

    private var scoreDistributionChart: some View
    {
        VStack(alignment: .leading, spacing: 12)
        {
            Label("分数段分布", systemImage: "chart.bar.xaxis.ascending")
                .font(.headline)
                .padding(.horizontal)

            let allGrades = vm.semesters.flatMap(\.grades)
            let distribution = buildScoreDistribution(allGrades)

            if distribution.isEmpty
            {
                Text("无百分制成绩数据")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            }
            else
            {
                Chart(distribution, id: \.range)
                { item in
                    BarMark(
                        x: .value("分数段", item.range),
                        y: .value("门数", item.count)
                    )
                    .foregroundStyle(barColor(for: item.range).gradient)
                    .annotation(position: .top)
                    {
                        Text("\(item.count)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                .chartXAxis
                {
                    AxisMarks(values: .automatic)
                    {
                        AxisValueLabel()
                            .font(.system(size: 9))
                    }
                }
                .frame(height: 180)
                .padding(.horizontal, 8)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func barColor(for range: String) -> Color
    {
        if range.contains("90") || range.contains("A") { return .green }
        if range.contains("80") || range.contains("B") { return .blue }
        if range.contains("70") || range.contains("C") { return .orange }
        if range.contains("60") || range.contains("D") { return .yellow }
        return .red
    }
}

private struct ScoreDistItem
{
    let range: String
    let count: Int
}

private func buildScoreDistribution(_ grades: [Grade]) -> [ScoreDistItem]
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
