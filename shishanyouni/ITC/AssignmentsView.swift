import SwiftUI

struct AssignmentsView: View
{
    let courseID: String
    let courseName: String

    @State private var currentAssignments: [ITC_Assignment] = []
    @State private var historyAssignments: [ITC_Assignment] = []
    @State private var isLoading = true
    @State private var isLoadingDetails = false
    @State private var errorMessage: String?

    var body: some View
    {
        Group
        {
            if isLoading
            {
                ProgressView("正在加载作业列表...")
                    .padding()
            }
            else if let error = errorMessage
            {
                VStack(spacing: 16)
                {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("重试") { Task { await load() } }
                        .buttonStyle(.borderedProminent)
                }
            }
            else if currentAssignments.isEmpty && historyAssignments.isEmpty
            {
                VStack(spacing: 16)
                {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("暂无作业")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            else
            {
                ScrollView
                {
                    LazyVStack(spacing: 0)
                    {
                        if !currentAssignments.isEmpty
                        {
                            sectionHeader("当前作业", systemImage: "clock.fill", color: .blue)
                            ForEach(currentAssignments)
                            { assignment in
                                NavigationLink(destination: AssignmentDetailView(assignment: assignment))
                                {
                                    AssignmentCard(assignment: assignment)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if !historyAssignments.isEmpty
                        {
                            sectionHeader("历史作业", systemImage: "clock.arrow.circlepath", color: .secondary)
                            ForEach(historyAssignments)
                            { assignment in
                                NavigationLink(destination: AssignmentDetailView(assignment: assignment))
                                {
                                    AssignmentCard(assignment: assignment)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .refreshable { await load() }
                .overlay
                {
                    if isLoadingDetails
                    {
                        VStack
                        {
                            Spacer()
                            HStack(spacing: 8)
                            {
                                ProgressView()
                                Text("正在加载详情...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
        }
        .navigationTitle(courseName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar
        {
            ToolbarItem(placement: .primaryAction)
            {
                Button(action: { Task { await load() } })
                {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task { await load() }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String, systemImage: String, color: Color) -> some View
    {
        HStack(spacing: 6)
        {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(color)
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(color)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 16)
        .padding(.bottom, 6)
    }

    // MARK: - Data loading

    private func load() async
    {
        isLoading = true
        errorMessage = nil

        do
        {
            let result = try await ITCFetch.shared.fetchAssignments(courseID: courseID)
            await MainActor.run
            {
                currentAssignments = result.current
                historyAssignments = result.history
                isLoading = false
            }
            await loadDetailsForAll()
        }
        catch
        {
            await MainActor.run
            {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func loadDetailsForAll() async
    {
        guard !currentAssignments.isEmpty || !historyAssignments.isEmpty else { return }

        await MainActor.run { isLoadingDetails = true }

        let all = currentAssignments + historyAssignments

        let enriched = await withTaskGroup(of: (String, ITC_Assignment?).self)
        { group in
            for assignment in all
            {
                group.addTask
                {
                    do
                    {
                        let detail = try await ITCFetch.shared.fetchAssignmentDetailForList(
                            courseID: assignment.courseID,
                            assignID: assignment.assignID
                        )
                        return (assignment.assignID, detail)
                    }
                    catch
                    {
                        print("加载作业 \(assignment.assignID) 详情失败: \(error)")
                        return (assignment.assignID, nil)
                    }
                }
            }

            var result: [String: ITC_Assignment] = [:]
            for await (id, detail) in group
            {
                if let detail { result[id] = detail }
            }
            return result
        }

        await MainActor.run
        {
            isLoadingDetails = false
            currentAssignments = currentAssignments.map
            { assignment in
                guard let detail = enriched[assignment.assignID] else { return assignment }
                return merge(assignment, with: detail)
            }
            historyAssignments = historyAssignments.map
            { assignment in
                guard let detail = enriched[assignment.assignID] else { return assignment }
                return merge(assignment, with: detail)
            }
        }
    }

    private func merge(_ base: ITC_Assignment, with detail: ITC_Assignment) -> ITC_Assignment
    {
        var result = base
        result.ddlTime = detail.ddlTime
        result.fullGrade = detail.fullGrade
        result.allQuestionsCount = detail.allQuestionsCount
        result.questionList = detail.questionList
        return result
    }
}

// MARK: - Assignment Card

private struct AssignmentCard: View
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
