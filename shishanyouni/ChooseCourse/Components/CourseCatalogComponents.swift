import Foundation
import SwiftUI

/// 顶部信息完全取自 Index / Display 的当次响应；没有读取到截止时间时明确说明，
/// 不使用固定日期或猜测的开课周期。
struct CourseSelectionHeaderCard: View
{
    let overview: CourseSelectionOverview
    let semester: SelectedCourseSemester

    private var title: String
    {
        let selectionTitle = overview.selectionTitle
        return selectionTitle.isEmpty ? "\(semester.displayName) 选课" : "\(selectionTitle) 选课"
    }

    var body: some View
    {
        VStack(alignment: .leading, spacing: 10)
        {
            Label(title, systemImage: "graduationcap.fill")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            TimelineView(.periodic(from: .now, by: 60))
            { timeline in
                if let countdown = overview.countdownText(at: timeline.date)
                {
                    Label(countdown, systemImage: "hourglass")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                else
                {
                    Label("教务页面暂未返回选课结束时间", systemImage: "hourglass.bottomhalf.filled")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}

/// 首层卡片没有“选课”按钮。轻点卡片展开后，用户能横向比较每个教学班的教师、时间、
/// 地点和容量，再点击那个具体教学班的按钮，降低误选概率。
struct CourseSearchResultRow: View
{
    let course: CourseSearchResult
    let isExpanded: Bool
    let teachingClasses: [CourseSearchResult]
    let isLoadingTeachingClasses: Bool
    let detailError: String?
    let onToggle: () -> Void
    let onRetryDetails: () -> Void
    let onSelectTeachingClass: (CourseSearchResult) -> Void
    /// 每个教学班单独计算已选状态，不能把同一课程的状态套到所有教学班。
    let selectedCourseFor: (CourseSearchResult) -> SelectedCourse?
    let onRequestDrop: (SelectedCourse) -> Void

    var body: some View
    {
        DisclosureGroup(isExpanded: Binding(
            get: { isExpanded },
            set: { if $0 != isExpanded { onToggle() } }
        ))
        {
            VStack(alignment: .leading, spacing: 12)
            {
                Divider().overlay(Color.secondary.opacity(0.22))

                if isLoadingTeachingClasses
                {
                    // 读取提示由页面中央统一呈现，展开卡片本身不再额外顶出一行加载框。
                    Color.clear
                        .frame(height: 1)
                }
                else if let detailError
                {
                    VStack(alignment: .leading, spacing: 8)
                    {
                        Label("教学班详情读取失败", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.yellow)
                        Text(detailError)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("重新读取", action: onRetryDetails)
                            .nativeGlassButtonStyle()
                    }
                    .padding(.vertical, 4)
                }
                else if teachingClasses.isEmpty
                {
                    Text("暂未读取到可展示的教学班。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                }
                else
                {
                    ScrollView(.horizontal, showsIndicators: false)
                    {
                        LazyHStack(alignment: .top, spacing: 12)
                        {
                            ForEach(teachingClasses)
                            { teachingClass in
                                TeachingClassSelectionCard(
                                    course: teachingClass,
                                    selectedCourse: selectedCourseFor(teachingClass),
                                    onSelect: { onSelectTeachingClass(teachingClass) },
                                    onRequestDrop: onRequestDrop
                                )
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        label:
        {
            VStack(alignment: .leading, spacing: 7)
            {
                Text(course.courseName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 7)
                {
                    if !course.courseCode.isEmpty
                    {
                        CourseCatalogTag(title: course.courseCode, color: .secondary)
                    }
                    if !course.credit.isEmpty
                    {
                        CourseCatalogTag(title: "\(course.credit) 学分", color: .secondary)
                    }
                    CourseCatalogTag(title: course.teachingClassCountText, color: .secondary)
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

/// 一个横滑教学班卡片。所有字段来自本次 `cxJxbWithKch` / PartDisplay 响应；
/// 缺字段时仅显示“暂未提供”，不把上一门课的数据错误复用过来。
private struct TeachingClassSelectionCard: View
{
    let course: CourseSearchResult
    let selectedCourse: SelectedCourse?
    let onSelect: () -> Void
    let onRequestDrop: (SelectedCourse) -> Void

    private var capacityStatus: CourseCapacityStatus { course.capacityStatus }

    private var actionTitle: String
    {
        if let selectedCourse
        {
            guard selectedCourse.dropAllowed, !selectedCourse.selectionTokens.isEmpty else
            {
                return "已选（暂不可退）"
            }
            return "退选"
        }
        return course.requiresChildClass ? "继续选择子课程" : "选课"
    }

    private var actionTint: Color
    {
        selectedCourse == nil ? capacityStatus.tint : .red
    }

    private var isActionEnabled: Bool
    {
        if let selectedCourse
        {
            return selectedCourse.dropAllowed && !selectedCourse.selectionTokens.isEmpty
        }
        // 正方第一轮等阶段可以“不限容量”，页面也可能显示已选人数大于容量。
        // 因此“已满”只能是红色状态提示，不能成为客户端的最终否决条件；
        // 按钮只在缺少本会话 token 时禁用，最终是否选上交由服务器返回并核验。
        return course.hasCurrentSelectionParameters
    }

    var body: some View
    {
        VStack(alignment: .leading, spacing: 10)
        {
            // 教学班是这张卡片的标题；其余信息按用户浏览教学安排的顺序向下排。
            Text(displayText(course.teachingClassName, fallback: course.courseName))
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)

            // 容量紧跟教学班标题；动作按钮只表达“选课/退选”，用户无需在页面底部
            // 再回头确认人数。
            CourseCapacityBadge(status: capacityStatus)

            VStack(alignment: .leading, spacing: 8)
            {
                let teacher = teacherText(course.teacherInfo)
                if teacher != "暂未提供"
                {
                    TeachingClassDetailLine(
                        icon: "person.fill",
                        title: "上课教师",
                        text: teacher,
                        textFont: .subheadline.weight(.medium),
                        textColor: .primary
                    )
                }
                if !course.teachingClassComposition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                {
                    TeachingClassDetailLine(
                        icon: "person.2.fill",
                        title: "教学班组成",
                        text: displayText(course.teachingClassComposition),
                        textFont: .subheadline.weight(.bold),
                        textColor: .primary
                    )
                }
                if !course.classTime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                {
                    TeachingClassDetailLine(icon: "calendar", title: "上课时间", text: displayText(course.classTime))
                }
                if !course.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                {
                    TeachingClassDetailLine(
                        icon: "mappin.and.ellipse",
                        title: "教学地点",
                        text: displayText(course.location),
                        textFont: .caption.weight(.semibold),
                        textColor: .primary
                    )
                }
                if !course.courseMaterial.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                {
                    TeachingClassDetailLine(icon: "book.closed", title: "课程教材", text: displayText(course.courseMaterial))
                }
                if !course.courseNature.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                {
                    TeachingClassDetailLine(icon: "tag", title: "课程性质", text: displayText(course.courseNature))
                }
                if !course.teachingMode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                {
                    TeachingClassDetailLine(icon: "rectangle.3.group", title: "教学模式", text: displayText(course.teachingMode))
                }
                if !course.selectionRemark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                {
                    TeachingClassDetailLine(icon: "text.alignleft", title: "选课备注", text: displayText(course.selectionRemark))
                }
            }

            Button
            {
                if let selectedCourse
                {
                    onRequestDrop(selectedCourse)
                }
                else
                {
                    onSelect()
                }
            } label: {
                Text(actionTitle)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .nativeGlassButtonStyle(prominent: true, fillsWidth: true, backgroundTint: actionTint)
            .tint(actionTint)
            .controlSize(.large)
            .disabled(!isActionEnabled)
            .accessibilityLabel(actionTitle)
            .accessibilityHint(selectedCourse != nil ? "需要再次确认后才会提交退选" : (course.requiresChildClass ? "下一步选择子课程" : "会先由教务系统核验再提交一次选课请求"))
        }
        .padding(14)
        .frame(width: 322, alignment: .leading)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func displayText(_ value: String, fallback: String = "暂未提供") -> String
    {
        let trimmed = value
            .replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "--" ? fallback : trimmed
    }

    private func teacherText(_ value: String) -> String
    {
        let pieces = value.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        if pieces.count >= 2, !pieces[1].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return pieces[1]
        }
        return displayText(value)
    }
}

/// 容量只以紧凑标签展示在教学班标题下方，颜色沿用余量档位，但不会改变整张卡片的中性灰外观。
private struct CourseCapacityBadge: View
{
    let status: CourseCapacityStatus

    var body: some View
    {
        Text(status.availabilityText)
            .font(.caption.weight(.semibold))
            .foregroundStyle(status.tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(status.tint.opacity(0.16), in: Capsule())
    }
}

private struct TeachingClassDetailLine: View
{
    let icon: String
    let title: String
    let text: String
    var textFont: Font = .caption
    var textColor: Color = .secondary

    var body: some View
    {
        HStack(alignment: .top, spacing: 7)
        {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 14, alignment: .center)
            Text("\(title)：\(text)")
                .font(textFont)
                .foregroundStyle(textColor)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct CourseCatalogTag: View
{
    let title: String
    let color: Color

    var body: some View
    {
        Text(title)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(color.opacity(0.14), in: Capsule())
    }
}
