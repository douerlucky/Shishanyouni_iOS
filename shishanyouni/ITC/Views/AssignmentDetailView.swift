import SwiftUI

struct AssignmentDetailView: View
{
    let assignment: ITC_Assignment

    @State private var detailAssignment: ITC_Assignment
    @State private var isLoading = true
    @State private var errorMessage: String?

    init(assignment: ITC_Assignment)
    {
        self.assignment = assignment
        _detailAssignment = State(initialValue: assignment)
    }

    var body: some View
    {
        Group
        {
            if isLoading
            {
                ProgressView("正在加载作业详情...")
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
                    Button("重试") { Task { await load() } }
                        .nativeGlassButtonStyle(prominent: true)
                }
            }
            else
            {
                List
                {
                    Section("作业信息")
                    {
                        infoRow(title: "作业名称", value: detailAssignment.assignName)
                        if let ddl = detailAssignment.ddlTime
                        {
                            infoRow(title: "截止时间", value: ddl)
                        }
                        if let grade = detailAssignment.fullGrade
                        {
                            infoRow(title: "满分", value: grade)
                        }
                        if let count = detailAssignment.allQuestionsCount
                        {
                            infoRow(title: "题目总数", value: "\(count)道")
                        }
                        infoRow(title: "已提交", value: "\(detailAssignment.completedCount) 题")
                        infoRow(title: "最终得分", value: detailAssignment.finalScore)
                    }

                    if let questions = detailAssignment.questionList, !questions.isEmpty
                    {
                        // 按 sectionType 分组，保持原始顺序，每组内独立编号
                        let sections = groupedSections(from: questions)
                        ForEach(sections, id: \.sectionType) { section in
                            Section
                            {
                                ForEach(Array(section.questions.enumerated()), id: \.element.id)
                                { idx, question in
                                    QuestionCard(question: question, index: idx + 1)
                                }
                            } header: {
                                HStack
                                {
                                    Text(section.sectionType.isEmpty ? "题目" : section.sectionType)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text("\(section.questions.count) 题")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("作业详情")
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

    // 按 sectionType 分组，保持原始顺序（不排序）
    private struct SectionGroup: Identifiable
    {
        let sectionType: String
        var questions: [ITC_Question]
        var id: String { sectionType }
    }

    private func groupedSections(from questions: [ITC_Question]) -> [SectionGroup]
    {
        var result: [SectionGroup] = []
        var seen: [String: Int] = [:]
        for q in questions
        {
            let key = q.sectionType
            if let idx = seen[key]
            {
                result[idx].questions.append(q)
            }
            else
            {
                seen[key] = result.count
                result.append(SectionGroup(sectionType: key, questions: [q]))
            }
        }
        return result
    }

    private func load() async
    {
        guard detailAssignment.questionList == nil else
        {
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do
        {
            let detail = try await ITCAPI.shared.fetchAssignmentDetail(
                courseID: assignment.courseID,
                assignID: assignment.assignID
            )
            await MainActor.run
            {
                detailAssignment.ddlTime = detail.ddlTime
                detailAssignment.fullGrade = detail.fullGrade
                detailAssignment.allQuestionsCount = detail.allQuestionsCount
                detailAssignment.questionList = detail.questionList
                isLoading = false
            }
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

    private func infoRow(title: String, value: String) -> some View
    {
        HStack
        {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}
