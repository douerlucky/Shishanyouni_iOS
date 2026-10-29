import SwiftUI

/// 成绩明细使用原生 Sheet，关闭、拖拽和背景由系统处理。
struct GradeDetailView: View
{
    @Environment(\.dismiss) private var dismiss
    let grade: Grade
    let cookie: String?
    let fallbackStudentID: String
    let fallbackYear: String
    let fallbackTerm: String
    let gradeService: GradeAPI

    @State private var components: [GradeComponent] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var detailComponents: [GradeComponent]
    {
        components.filter { !$0.isOverallScore }
    }

    private var overallScore: String
    {
        components.first(where: \.isOverallScore)?.scoreText ?? grade.cj
    }

    var body: some View
    {
        VStack(spacing: 16)
        {
            if isLoading
            {
                ProgressView("正在加载成绩明细…")
                    .frame(maxWidth: .infinity, minHeight: 180)
            }
            else if let errorMessage
            {
                VStack(spacing: 10)
                {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 28))
                        .foregroundStyle(.orange)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
            }
            else
            {
                GradeCompositionRing(
                    components: detailComponents,
                    overallScore: overallScore
                )
                .frame(width: 132, height: 132)

                ScrollView
                {
                    VStack(spacing: 14)
                    {
                        ForEach(detailComponents)
                        { component in
                            GradeComponentRow(component: component)
                        }

                        if detailComponents.isEmpty
                        {
                            Text("教务系统没有返回成绩组成项")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle(grade.kcmc)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar
        {
            ToolbarItem(placement: .confirmationAction)
            {
                Button("完成") { dismiss() }
            }
        }
        .task(id: grade.id)
        {
            await loadComponents()
        }
    }

    private func loadComponents() async
    {
        isLoading = true
        errorMessage = nil

        do
        {
            components = try await gradeService.fetchGradeComponents(
                for: grade,
                cookie: cookie,
                fallbackStudentID: fallbackStudentID,
                fallbackYear: fallbackYear,
                fallbackTerm: fallbackTerm
            )
        }
        catch
        {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
