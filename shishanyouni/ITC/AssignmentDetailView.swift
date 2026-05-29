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
                        .buttonStyle(.borderedProminent)
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
            let detail = try await ITCFetch.shared.fetchAssignmentDetail(
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

private struct QuestionCard: View
{
    let question: ITC_Question
    var index: Int = 0   // 区块内序号，0 = 不显示

    var body: some View
    {
        VStack(alignment: .leading, spacing: 10)
        {
            HStack(alignment: .top)
            {
                if index > 0
                {
                    Text("\(index).")
                        .font(.body)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .frame(minWidth: 24, alignment: .leading)
                }
                Text(question.name)
                    .font(.body)
                    .fontWeight(.semibold)
                Spacer()
                if question.grade != "-"
                {
                    Text("\(question.grade) / \(question.questionFullGrade)")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundColor(gradeColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(gradeColor.opacity(0.1))
                        .cornerRadius(6)
                }
                else if question.hasSubmitted
                {
                    Text("已提交")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(6)
                }
                else if question.questionFullGrade != "-"
                {
                    Text("- / \(question.questionFullGrade)")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                }
            }

            if question.grade == "-" && question.hasSubmitted
            {
                HStack(spacing: 16)
                {
                    if question.firstSubmitTime != "-"
                    {
                        Label("初次: \(question.firstSubmitTime)", systemImage: "arrow.up.doc")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if question.lastUpdate != "-"
                    {
                        Label("最近: \(question.lastUpdate)", systemImage: "clock.arrow.circlepath")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            else
            {
                if question.lastUpdate != "-"
                {
                    Label(question.lastUpdate, systemImage: "clock.arrow.circlepath")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if !question.testData.isEmpty
            {
                Divider()
                Text("测试数据")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach(question.testData) { td in
                    HStack
                    {
                        Text(td.dataID)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(td.correctStatus)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(td.isCorrect ? .green : .red)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var gradeColor: Color
    {
        guard let g = Double(question.grade), let f = Double(question.questionFullGrade), f > 0 else { return .secondary }
        let ratio = g / f
        if ratio >= 1.0 { return .green }
        if ratio >= 0.6 { return .orange }
        return .red
    }
}
