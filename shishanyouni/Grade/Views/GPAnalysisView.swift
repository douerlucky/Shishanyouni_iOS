import SwiftUI
import Charts

// MARK: - GPA Analysis View

struct GPAnalysisView: View
{
    @EnvironmentObject var userinfo: userInfo
    @EnvironmentObject var iapStore: IAPStore
    @StateObject private var vm = GPAnalysisViewModel()
    @StateObject private var backendMFA = ShishanyouniMFAPresenter()

    var body: some View
    {
        Group
        {
            if !iapStore.hasActiveSubscription
            {
                SubscriptionView()
            }
            else if vm.isLoading
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
                            encryptedPassword: userinfo.encryptedPasswordShishanyouni,
                            mfa: backendMFA.provider
                        )}
                    }
                    .nativeGlassButtonStyle(prominent: true)
                }
                .padding(32)
            }
            else
            {
                contentView
            }
        }
        .shishanyouniMFA(backendMFA)
        .navigationTitle("GPA 分析")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .background(Color(uiColor: .systemGroupedBackground))
        .task {
            if iapStore.hasActiveSubscription, vm.semesters.isEmpty
            {
                await vm.fetchAllSemesters(
                    username: userinfo.username,
                    encryptedPassword: userinfo.encryptedPasswordShishanyouni,
                    mfa: backendMFA.provider
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
                    .foregroundColor(gradeAnalysisSummaryGpaColor(vm.overallGPA))
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
