import Foundation
import SwiftUI

struct SelectedCourseView: View
{
    let courses: [SelectedCourse]
    let unmatchedSchedules: [SelectedCourseScheduleEntry]
    let semester: SelectedCourseSemester
    let overview: CourseSelectionOverview
    let isLoading: Bool
    let errorMessage: String?
    let onRetry: () -> Void
    let onDrop: (SelectedCourse) -> Void

    /// 网页初始 DOM 中的 yxxfs 可能尚未被 JS 更新。已选列表是更可靠的当前真值，
    /// 所以进入“已选科目”后以本次列表的学分和覆盖它。
    private var creditOverview: CourseSelectionOverview
    {
        overview.replacingSelectedCredit(with: selectedCreditTotal)
    }

    private var selectedCreditTotal: Double
    {
        courses.reduce(0)
        { total, course in
            let normalized = (course.displayCredit ?? "")
                .replacingOccurrences(of: "，", with: ".")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return total + (Double(normalized) ?? 0)
        }
    }

    var body: some View
    {
        Group
        {
            Section
            {
                SelectedCreditOverviewCard(overview: creditOverview)
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 8, trailing: 12))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if !unmatchedSchedules.isEmpty
            {
                Section
                {
                    Label {
                        VStack(alignment: .leading, spacing: 4)
                        {
                            Text("发现 \(unmatchedSchedules.count) 条课表补充安排")
                                .font(.subheadline.weight(.semibold))
                            Text("这些安排已计入空闲度概览；因教务系统未返回可精确对应的主教学班，不会显示为可退选课程。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "flask.fill")
                            .foregroundStyle(.orange)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }

            Section
            {
                if isLoading, courses.isEmpty
                {
                    // 已选页使用外层统一的居中加载框；保留极小占位可避免在请求开始的
                    // 同一渲染帧闪出“暂无已选课程”。
                    Color.clear
                        .frame(height: 1)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                else if let errorMessage
                {
                    VStack(alignment: .leading, spacing: 10)
                    {
                        Label("暂时无法读取已选课程", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundStyle(.orange)
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("重试", action: onRetry)
                            .nativeGlassButtonStyle()
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                else if courses.isEmpty
                {
                    VStack(alignment: .leading, spacing: 6)
                    {
                        Text("暂无已选课程")
                            .font(.headline)
                        Text("\(semester.displayName) 未查询到已选课程。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                else
                {
                    ForEach(courses)
                    { course in
                        SelectedCourseRow(course: course, onDrop: { onDrop(course) })
                            .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
            } header: {
                HStack
                {
                    Text("已选课程 · \(semester.displayName)")
                    Spacer()
                    if !courses.isEmpty
                    {
                        Text("共 \(courses.count) 门")
                    }
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(nil)
            }
        }
    }
}
