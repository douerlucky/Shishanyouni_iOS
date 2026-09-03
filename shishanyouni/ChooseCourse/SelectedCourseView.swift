//
//  SelectedCourseView.swift
//  shishanyouni
//
//  已选课程展示区。退选按钮只发起确认流程，真正写操作统一交给 CourseEdit。
//

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
                            .buttonStyle(.bordered)
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

/// 环形进度沿用成绩页的圆环语言：轨道 + 圆角进度端点；只是上限改为教务返回的
/// “本学期最高学分”，从而能直接看出当前选课距离上限还有多少空间。
private struct SelectedCreditOverviewCard: View
{
    let overview: CourseSelectionOverview

    private var selectedCredit: Double { overview.selectedCredit ?? 0 }
    private var maximumCredit: Double { max(overview.maximumCredit ?? max(selectedCredit, 1), 1) }
    private var progress: Double { min(max(selectedCredit / maximumCredit, 0), 1) }

    var body: some View
    {
        HStack(spacing: 16)
        {
            ZStack
            {
                Circle()
                    .stroke(Color.secondary.opacity(0.20), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.primary.opacity(0.72), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.55), value: selectedCredit)
                VStack(spacing: 1)
                {
                    Text(creditText(selectedCredit))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("本学期已选")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 96, height: 96)

            VStack(alignment: .leading, spacing: 9)
            {
                Text("选课学分概览")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("本学期已选 \(overview.selectedCreditText) 学分")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                HStack(spacing: 14)
                {
                    CreditMetric(label: "已获得", value: overview.earnedCreditText)
                    CreditMetric(label: "最低", value: creditText(overview.minimumCredit))
                    CreditMetric(label: "最高", value: creditText(overview.maximumCredit))
                }
                Text("选课要求：\(overview.creditRangeText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    private func creditText(_ value: Double?) -> String
    {
        guard let value else { return "--" }
        return value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }
}

private struct CreditMetric: View
{
    let label: String
    let value: String

    var body: some View
    {
        VStack(alignment: .leading, spacing: 1)
        {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
        }
    }
}

private struct SelectedCourseRow: View
{
    let course: SelectedCourse
    let onDrop: () -> Void

    var body: some View
    {
        VStack(alignment: .leading, spacing: 12)
        {
            HStack(alignment: .top, spacing: 12)
            {
                VStack(alignment: .leading, spacing: 4)
                {
                    Text(course.courseName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)

                    if let teachingClassName = course.displayTeachingClassName
                    {
                        Text(teachingClassName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 8)
                {
                    if let courseCode = course.displayCourseCode
                    {
                        Text(courseCode)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .textSelection(.enabled)
                    }

                    Button("退选", role: .destructive, action: onDrop)
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .controlSize(.small)
                        .disabled(!course.dropAllowed || course.selectionTokens.isEmpty)
                        .accessibilityHint(course.dropAllowed && !course.selectionTokens.isEmpty ? "需要再次确认后才会提交" : "教务系统未返回可用退选参数")
                }
            }

            HStack(spacing: 8)
            {
                if let type = course.displayCourseType
                {
                    SelectedCourseTag(title: type, color: .secondary)
                }
                if let credit = course.displayCredit
                {
                    SelectedCourseTag(title: "\(credit) 学分", color: .secondary)
                }
                if let enrollment = course.enrollmentText
                {
                    SelectedCourseTag(title: enrollment, color: .secondary)
                }
            }

            VStack(alignment: .leading, spacing: 7)
            {
                SelectedCourseMetaRow(icon: "person.fill", text: course.teacherName)
                if let time = course.displayClassTime
                {
                    SelectedCourseMetaRow(icon: "calendar", text: time)
                }
                if let location = course.displayLocation
                {
                    SelectedCourseMetaRow(icon: "mappin.and.ellipse", text: location)
                }
            }

            if !course.supplementalSchedules.isEmpty
            {
                Divider()

                VStack(alignment: .leading, spacing: 9)
                {
                    Label("课表补充安排", systemImage: "flask.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    ForEach(course.supplementalSchedules)
                    { schedule in
                        SelectedCourseSupplementalScheduleRow(schedule: schedule)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}

/// 实验、上机等子教学班只读地附在主课程下；退选仍只针对已选接口明确返回的主课程。
private struct SelectedCourseSupplementalScheduleRow: View
{
    let schedule: SelectedCourseScheduleEntry

    var body: some View
    {
        VStack(alignment: .leading, spacing: 5)
        {
            if let teachingClass = schedule.displayTeachingClassName
            {
                Text(teachingClass)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }
            else if schedule.courseName != "课表安排"
            {
                Text(schedule.courseName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }

            if let teacher = schedule.displayTeacher
            {
                SelectedCourseMetaRow(icon: "person.fill", text: teacher)
            }
            SelectedCourseMetaRow(icon: "calendar", text: schedule.classTime)
            if let location = schedule.displayLocation
            {
                SelectedCourseMetaRow(icon: "mappin.and.ellipse", text: location)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

private struct SelectedCourseTag: View
{
    let title: String
    let color: Color

    var body: some View
    {
        Text(title)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.16), in: Capsule())
    }
}

private struct SelectedCourseMetaRow: View
{
    let icon: String
    let text: String

    var body: some View
    {
        Label(text, systemImage: icon)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
    }
}

/// 从选课主页右上角进入的“已选科目”页面。
/// 课程目录和已选列表分开加载，打开选课主页时不会额外请求一次已选课程接口。
struct SelectedCourseListScreen: View
{
    let courses: [SelectedCourse]
    let unmatchedSchedules: [SelectedCourseScheduleEntry]
    let semester: SelectedCourseSemester
    let overview: CourseSelectionOverview
    let isLoading: Bool
    let errorMessage: String?
    let onRetry: () -> Void
    let onRefresh: () async -> Void
    let onDrop: (SelectedCourse) -> Void

    var body: some View
    {
        ZStack
        {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            List
            {
                SelectedCourseView(
                    courses: courses,
                    unmatchedSchedules: unmatchedSchedules,
                    semester: semester,
                    overview: overview,
                    isLoading: isLoading,
                    errorMessage: errorMessage,
                    onRetry: onRetry,
                    onDrop: onDrop
                )
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            if isLoading, courses.isEmpty
            {
                CourseCenteredLoadingOverlay(message: "正在读取已选课程…")
            }
        }
        .navigationTitle("已选科目")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar
        {
            ToolbarItemGroup(placement: .topBarTrailing)
            {
                NavigationLink
                {
                    CourseAvailabilityOverviewView(
                        courses: courses,
                        semester: semester,
                        supplementarySchedules: unmatchedSchedules
                    )
                }
                label:
                {
                    Image(systemName: "calendar.badge.clock")
                }
                .disabled(courses.isEmpty && unmatchedSchedules.isEmpty)
                .accessibilityLabel("空闲度概览")

                Button
                {
                    Task { await onRefresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
                .accessibilityLabel("刷新已选科目")
            }
        }
        .refreshable
        {
            await onRefresh()
        }
        .task
        {
            // 页面每次打开都重新核验一次，确保退选/网页端变更能马上反映。
            await onRefresh()
        }
    }
}
