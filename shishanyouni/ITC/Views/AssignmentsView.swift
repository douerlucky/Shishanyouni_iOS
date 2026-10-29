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
                        .nativeGlassButtonStyle(prominent: true)
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
            let result = try await ITCAPI.shared.fetchAssignments(courseID: courseID)
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
                        let detail = try await ITCAPI.shared.fetchAssignmentDetailForList(
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
