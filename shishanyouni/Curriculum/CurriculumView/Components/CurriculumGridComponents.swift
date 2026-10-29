import Combine
import SwiftUI
import UIKit

let curriculumCellHeight: CGFloat = 58
let curriculumTimeColumnWidth: CGFloat = 60
let curriculumGridPadding: CGFloat = 10

/// 星期条、周数条和收起按钮共用系统玻璃；普通底色只在未绘制玻璃时使用。
private struct CurriculumGlassPanel<S: InsettableShape>: ViewModifier
{
    let shape: S
    let enabled: Bool


    func body(content: Content) -> some View
    {
        content
            .optionalLiquidGlass(
                enabled: enabled,
                in: shape,
                fallback: Color(.secondarySystemBackground).opacity(0.5)
            )
    }
}

extension View
{
    /// 课表页的共用材质入口，玻璃外观由系统决定。
    func curriculumGlassPanel<S: InsettableShape>(in shape: S, enabled: Bool) -> some View
    {
        modifier(CurriculumGlassPanel(shape: shape, enabled: enabled))
    }
}

/// 课表与设置预览共用的基础字号，教室和老师允许最多两行。
enum CurriculumTypography
{
    static let courseName: CGFloat = 11
    static let courseDetail: CGFloat = 9
    static let periodTitle: CGFloat = 15
    static let extraPeriodTitle: CGFloat = 12
    static let periodTime: CGFloat = 11
}

/// 同一个显示比例同时控制格子高度和格内文字，避免设置预览与真实课表不一致。
private func curriculumDisplayScale(_ value: Double) -> CGFloat
{
    CGFloat(min(max(value, 0.65), 1.5))
}

func curriculumCellHeight(for fontScale: Double) -> CGFloat
{
    curriculumCellHeight * curriculumDisplayScale(fontScale)
}

/// 底部控制条里“上一周 / 下一周”共用的同一枚按钮。
///
/// 左右两枚只差一个方向和一个禁用条件，抽成同一个组件后样式只有一处定义。
/// 使用统一的 NextButton，图标只使用 chevron 本身，圆形外观完全由按钮组件提供。
struct WeekStepButton: View
{
    let systemName: String
    let isDisabled: Bool
    let action: () -> Void

    var body: some View
    {
        NextButton(
            systemImage: systemName,
            tint: appActionBlue,
            size: 34,
            action: action
        )
        .disabled(isDisabled)
    }
}

// 星期头

struct WeekHeaderView: View
{
    let weekDays = ["一", "二", "三", "四", "五", "六", "日"]
    @Binding var weekDatesCurWeek: [Date]
    @Binding var datesCurWeek: [Int]

    var body: some View
    {
        HStack(spacing: 0)
        {
            ForEach(0 ..< 7, id: \.self)
            { index in
                let isToday = Calendar.current.isDateInToday(weekDatesCurWeek[index])
                VStack(spacing: 4)
                {
                    Text(weekDays[index])
                        .font(.system(size: 13, weight: isToday ? .bold : .medium, design: .rounded))
                        .foregroundColor(isToday ? .white : .secondary)
                        .appTextOpacity()
                        .frame(maxWidth: .infinity)
                    Text("\(datesCurWeek[index])")
                        .font(.system(size: 10, weight: isToday ? .bold : .regular, design: .rounded))
                        .foregroundColor(isToday ? .white : .secondary)
                        .appTextOpacity()
                }
                .padding(.vertical, 8)
                .background
                {
                    // 保留系统蓝的状态语义，但不在玻璃下面另铺蓝色实底。
                    if isToday
                    {
                        Color.clear
                            .optionalLiquidGlass(
                                allowsNesting: true,
                                in: Capsule(),
                                tint: appActionBlue,
                                fallback: appActionBlue
                            )
                    }
                    else
                    {
                        Capsule().fill(Color.clear)
                    }
                }
            }
        }
    }

}

// CourseGridView
// 每天一个 VStack，按统一的显示顺序渲染：1–4 节、中午、5–8 节、晚上、9–12 节。
// 课程起始节次渲染课程卡片，跳过后续被占节次
// 空白节次渲染空白格子
// 所有元素在同一个vstack里，同一层级无任何重叠
// 课程卡片内部用background 没有ZStack了

struct CourseGridView: View
{
    let courses: [Course]
    let nowdisplayWeek: Int
    let fontScale: Double
    let visiblePeriods: [Int]

    var onDeleteCourse: ((Course) -> Void)?
    var onEditCourse: ((Course) -> Void)?
    var onLongPressEmptyCell: ((Int, Int) -> Void)?
    var onAddCourseFromCard: ((Course) -> Void)?
    /// 课程卡片把整个冲突组一并交回父 View，父 View 负责持久化 priority。
    var onSetCoursePriority: ((Course, [Course]) -> Void)?
    @AppStorage("enableLiquidGlassEffect") private var enableLiquidGlassEffect: Bool = false
    private let weekdayNames = ["一", "二", "三", "四", "五", "六", "日"]

    init(
        courses: [Course],
        nowdisplayWeek: Int,
        fontScale: Double = 1.0,
        visiblePeriods: [Int] = CurriculumClassSchedule.displayOrder,
        onDeleteCourse: ((Course) -> Void)? = nil,
        onEditCourse: ((Course) -> Void)? = nil,
        onLongPressEmptyCell: ((Int, Int) -> Void)? = nil,
        onAddCourseFromCard: ((Course) -> Void)? = nil,
        onSetCoursePriority: ((Course, [Course]) -> Void)? = nil
    )
    {
        self.courses = courses
        self.nowdisplayWeek = nowdisplayWeek
        self.fontScale = fontScale
        self.visiblePeriods = visiblePeriods
        self.onDeleteCourse = onDeleteCourse
        self.onEditCourse = onEditCourse
        self.onLongPressEmptyCell = onLongPressEmptyCell
        self.onAddCourseFromCard = onAddCourseFromCard
        self.onSetCoursePriority = onSetCoursePriority
    }

    var body: some View
    {
        HStack(spacing: 0)
        {
            ForEach(1 ... 7, id: \.self)
            { day in
                let dayCourses = coursesForDay(day)
                // 把day传进去，这样空白格子的day一定是正确的
                let slots = buildSlots(day: day, dayCourses: dayCourses)

                VStack(spacing: 0)
                {
                    ForEach(slots, id: \.id)
                    { slot in
                        switch slot.kind
                        {
                        case let .course(course, conflicts):
                            courseCardView(course: course, conflicts: conflicts)

                        case let .empty(emptyDay, period):
                            emptyCellView(day: emptyDay, period: period)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Slot 数据结构

    struct RenderSlot: Identifiable
    {
        let id: String
        let kind: SlotKind
    }

    enum SlotKind
    {
        /// winner 全宽显示，conflicts 为同时段被压住的课程（不渲染卡片，仅 Preview 展示）
        case course(Course, conflicts: [Course])
        case empty(day: Int, period: Int)
    }

    private func coursesForDay(_ day: Int) -> [Course]
    {
        return courses.filter { $0.hasScheduledTime && $0.day == day && $0.parsedWeeks.contains(nowdisplayWeek) }
    }

    // 按正式显示顺序扫描，生成渲染列表。
    // day从外层ForEach传入，保证空白格子的day永远正确
    private func buildSlots(day: Int, dayCourses: [Course]) -> [RenderSlot]
    {
        // 将冲突解析结果映射到 startPeriod
        // key = 胜者的 start，value = (winner, [conflicts])
        var startMap: [Int: (Course, [Course])] = [:]
        let resolved = resolveConflictsForDay(dayCourses)
        for (winner, conflicts) in resolved
        {
            startMap[winner.start] = (winner, conflicts)
        }

        var slots: [RenderSlot] = []
        var displayIndex = 0

        while displayIndex < visiblePeriods.count
        {
            let period = visiblePeriods[displayIndex]

            if let (winner, conflicts) = startMap[period]
            {
                slots.append(RenderSlot(
                    id: "c_\(winner.id)_\(period)",
                    kind: .course(winner, conflicts: conflicts)
                ))
                let span = CurriculumClassSchedule.displayPeriods(
                        start: winner.start,
                        end: winner.endPeriod
                    )
                    .filter(visiblePeriods.contains)
                    .count
                guard span > 0
                else
                {
                    displayIndex += 1
                    continue
                }
                displayIndex += span
            }
            else
            {
                slots.append(RenderSlot(
                    id: "e_\(day)_\(period)",
                    kind: .empty(day: day, period: period)
                ))
                displayIndex += 1
            }
        }

        return slots
    }

    // MARK: - 冲突检测与解析

    /// 两课程在课表可见行上是否有任意重叠。
    /// 普通课程可覆盖中午或晚上，因此不能只用 1–12 的数字范围比较。
    private func overlaps(_ a: Course, _ b: Course) -> Bool
    {
        let aPeriods = Set(CurriculumClassSchedule.displayPeriods(
            start: a.start,
            end: a.endPeriod
        ))
        let bPeriods = Set(CurriculumClassSchedule.displayPeriods(
            start: b.start,
            end: b.endPeriod
        ))
        return !aPeriods.isDisjoint(with: bPeriods)
    }

    /// 包含型和贯穿型的统一胜者选择：用户优先级 → 节数 → 导入课。
    private func winner(_ a: Course, _ b: Course) -> Course
    {
        if a.displayPriority != b.displayPriority
        {
            return a.displayPriority > b.displayPriority ? a : b
        }
        if a.step != b.step { return a.step > b.step ? a : b }
        return a.isManual ? b : a
    }

    /// 解析单天课程的所有冲突，返回 [(展示的胜者, [被压住的课程])]
    /// 无冲突的课程以空 conflicts 列表返回
    private func resolveConflictsForDay(_ courses: [Course]) -> [(Course, [Course])]
    {
        guard courses.count > 1
        else
        {
            return courses.map { ($0, []) }
        }

        // 按 start 升序排列
        let sorted = courses.sorted { $0.start < $1.start }

        // 用 Union-Find 思路：将所有互相重叠的课程归入同一组
        var groupID = Array(0 ..< sorted.count) // 每个元素的组号
        func find(_ i: Int) -> Int
        {
            var i = i
            while groupID[i] != i { i = groupID[i] }
            return i
        }
        func union(_ i: Int, _ j: Int)
        {
            groupID[find(i)] = find(j)
        }

        for i in 0 ..< sorted.count
        {
            for j in (i + 1) ..< sorted.count
            {
                if overlaps(sorted[i], sorted[j]) { union(i, j) }
            }
        }

        // 按组收集
        var groups: [Int: [Course]] = [:]
        for (idx, course) in sorted.enumerated()
        {
            let g = find(idx)
            groups[g, default: []].append(course)
        }

        // 每组选出胜者
        var result: [(Course, [Course])] = []
        for (_, group) in groups
        {
            if group.count == 1
            {
                result.append((group[0], []))
            }
            else
            {
                let w = group.reduce(group[0]) { winner($0, $1) }
                let losers = group.filter { $0.id != w.id }
                result.append((w, losers))
            }
        }

        return result
    }

    // 空白格子

    @ViewBuilder
    private func emptyCellView(day: Int, period: Int) -> some View
    {
        
        Color.clear
            .frame(height: curriculumCellHeight(for: fontScale))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .optionalLiquidGlass(
                enabled: enableLiquidGlassEffect,
                cornerRadius: 12,
                fallback: Color(.systemGray6).opacity(0.4)
            )
            .padding(1)
            .contentShape(Rectangle())
            .contextMenu
            {
                Button
                {
                    onLongPressEmptyCell?(day, period)
                } label: {
                    Label("添加课程", systemImage: "plus.circle")
                }
            } preview: {
                emptyCellPreview(day: day, period: period)
            }
    }

    @ViewBuilder
    private func emptyCellPreview(day: Int, period: Int) -> some View
    {
        emptyCellPreviewContent(day: day, period: period)
            .optionalLiquidGlass(
                enabled: enableLiquidGlassEffect,
                in: RoundedRectangle(cornerRadius: 22, style: .continuous),
                fallback: Color(uiColor: .secondarySystemBackground)
            )
            .environment(\.isInsideLiquidGlassSurface, false)
    }

    private func emptyCellPreviewContent(day: Int, period: Int) -> some View
    {
        VStack(spacing: 4)
        {
            Image(systemName: "plus.circle.fill")
                .font(.largeTitle)
                .foregroundColor(appActionBlue)
            Text("周\(weekdayNames[day - 1]) \(CurriculumClassSchedule.displayName(for: period))")
                .font(.headline)
        }
        .padding(20)
    }

    // MARK: - 课程卡片（同一层级，无 ZStack，用 .background 实现背景色）

    @ViewBuilder
    private func courseCardView(course: Course, conflicts: [Course] = []) -> some View
    {
        // 时段设置隐藏中午或晚上后，课程卡片也必须只占可见行的高度，
        // 否则跨过该时段的课程会与后面的网格错位。
        let spans = CGFloat(max(
            CurriculumClassSchedule.displayPeriods(
                start: course.start,
                end: course.endPeriod
            )
            .filter(visiblePeriods.contains)
            .count,
            1
        ))
        let cellHeight = curriculumCellHeight(for: fontScale)
        let cardHeight = spans * cellHeight + (spans - 1) * 2
        let color = courseColor(for: course)
        let scale = curriculumDisplayScale(fontScale)

        VStack(spacing: 4 * scale)
        {
            Spacer(minLength: 2 * scale)


            let shortName = course.shortName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            Text(shortName.isEmpty ? course.name : shortName)
                .font(.system(size: CurriculumTypography.courseName * scale, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(4)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)
                .appTextOpacity()
                .frame(maxWidth: .infinity, alignment: .center)

            // 极紧凑的单节格优先保留课程名；完整信息仍可在长按预览中查看。
            if cardHeight >= 55, let room = course.room
            {
                HStack(alignment: .center, spacing: 2 * scale)
                {
                    Image(systemName: "location.fill")
                        // 图标随缩小比例变化，放大时最多保持 100% 的尺寸。
                        .font(.system(size: CurriculumTypography.courseDetail * min(scale, 1)))
                    Text(room)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .multilineTextAlignment(.center)
                        .appTextOpacity()
                }
                .font(.system(size: CurriculumTypography.courseDetail * scale))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .center)
            }

            if cardHeight >= 55, let teacher = course.teacher
            {
                HStack(alignment: .center, spacing: 2 * scale)
                {
                    Image(systemName: "person.fill")
                        .font(.system(size: CurriculumTypography.courseDetail * min(scale, 1)))
                    Text(teacher)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .multilineTextAlignment(.center)
                        .appTextOpacity()
                }
                .font(.system(size: CurriculumTypography.courseDetail * scale))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            Spacer(minLength: 2 * scale)
        }

        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity)
        .frame(height: cardHeight)

        .clipShape(RoundedRectangle(cornerRadius: 12))
        .optionalLiquidGlass(
            enabled: enableLiquidGlassEffect,
            cornerRadius: 12,
            tint: color,
            fallback: color.opacity(0.85)
        )
        .overlay(alignment: .topTrailing)
        {
            if !conflicts.isEmpty
            {
                Text("\(conflicts.count + 1)")
                    .font(.system(size: CurriculumTypography.courseDetail * scale, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 16 * scale, height: 16 * scale)
                    .background(Circle().fill(Color.orange))
                    .padding(4 * scale)
            }
        }

        .padding(1)
        .contentShape(Rectangle())

        .contextMenu
        {
            if !conflicts.isEmpty
            {
                let conflictGroup = [course] + conflicts
                Menu
                {
                    ForEach(conflictGroup)
                    { candidate in
                        let shortName = candidate.shortName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                        Button
                        {
                            onSetCoursePriority?(candidate, conflictGroup)
                        } label: {
                            Label(
                                shortName.isEmpty ? candidate.name : shortName,
                                systemImage: candidate.displayPriority == 1 ? "checkmark.star.fill" : "star"
                            )
                        }
                    }
                } label: {
                    Label("优先显示课程", systemImage: "star")
                }
            }

            Button
            {
                onEditCourse?(course)
            } label: {
                Label("编辑", systemImage: "pencil")
            }

            Button
            {
                onAddCourseFromCard?(course)
            } label: {
                Label("添加课程", systemImage: "plus.circle")
            }

            Button(role: .destructive)
            {
                onDeleteCourse?(course)
            } label: {
                Label("删除", systemImage: "trash")
            }
        } preview: {
            CourseCardPreview(course: course, week: nowdisplayWeek, conflicts: conflicts)
        }
    }

    // MARK: - 课程颜色

    private func courseColor(for course: Course) -> Color
    {
        // 优先使用用户自定义颜色
        if let hex = course.customColorHex, let custom = Color(hex: hex)
        {
            return custom
        }

        let colors: [Color] = [
            .blue, .green, .orange, .purple,
            .pink, .red, .yellow, .gray,
            .teal, .indigo, .cyan, .mint,
            .brown,
            Color.adaptive(light: Color(red: 0.5, green: 0.2, blue: 0.8), dark: Color(red: 0.65, green: 0.35, blue: 0.88)),
            Color.adaptive(light: Color(red: 0.9, green: 0.3, blue: 0.5), dark: Color(red: 0.94, green: 0.45, blue: 0.60)),
            Color.adaptive(light: Color(red: 0.2, green: 0.6, blue: 0.4), dark: Color(red: 0.35, green: 0.70, blue: 0.50)),
            Color.adaptive(light: Color(red: 0.4, green: 0.7, blue: 0.9), dark: Color(red: 0.55, green: 0.78, blue: 0.92)),
            Color.adaptive(light: Color(red: 0.7, green: 0.5, blue: 0.9), dark: Color(red: 0.78, green: 0.60, blue: 0.92)),
            Color.adaptive(light: Color(red: 0.9, green: 0.6, blue: 0.4), dark: Color(red: 0.94, green: 0.68, blue: 0.50)),
            Color.adaptive(light: Color(red: 0.5, green: 0.8, blue: 0.6), dark: Color(red: 0.60, green: 0.85, blue: 0.68)),
            Color.adaptive(light: Color(red: 0.9, green: 0.5, blue: 0.6), dark: Color(red: 0.94, green: 0.60, blue: 0.68)),
            Color.adaptive(light: Color(red: 0.6, green: 0.4, blue: 0.7), dark: Color(red: 0.72, green: 0.52, blue: 0.78)),
            Color.adaptive(light: Color(red: 0.3, green: 0.5, blue: 0.7), dark: Color(red: 0.45, green: 0.62, blue: 0.78)),
            Color.adaptive(light: Color(red: 0.8, green: 0.6, blue: 0.3), dark: Color(red: 0.88, green: 0.68, blue: 0.42)),
            Color.adaptive(light: Color(red: 0.2, green: 0.3, blue: 0.5), dark: Color(red: 0.38, green: 0.48, blue: 0.65)),
            Color.adaptive(light: Color(red: 0.3, green: 0.5, blue: 0.3), dark: Color(red: 0.45, green: 0.62, blue: 0.42)),
            Color.adaptive(light: Color(red: 0.6, green: 0.3, blue: 0.2), dark: Color(red: 0.75, green: 0.48, blue: 0.38)),
            Color.adaptive(light: Color(red: 0.5, green: 0.2, blue: 0.4), dark: Color(red: 0.68, green: 0.38, blue: 0.55)),
            Color.adaptive(light: Color(red: 0.2, green: 0.5, blue: 0.5), dark: Color(red: 0.38, green: 0.62, blue: 0.62)),
            Color.adaptive(light: Color(red: 0.5, green: 0.4, blue: 0.2), dark: Color(red: 0.65, green: 0.55, blue: 0.35)),
            Color.adaptive(light: Color(red: 0.4, green: 0.2, blue: 0.5), dark: Color(red: 0.58, green: 0.38, blue: 0.65)),
            Color.adaptive(light: Color(red: 0.6, green: 0.2, blue: 0.3), dark: Color(red: 0.75, green: 0.38, blue: 0.48)),
        ]
        return colors[course.colorRandom % colors.count]
    }
}

// MARK: - 长按课程卡片预览

struct CourseCardPreview: View
{
    let course: Course
    let week: Int
    var conflicts: [Course] = []

    private let weekdays = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]

    @ViewBuilder
    var body: some View
    {
        // 系统菜单保持原生样式；自定义预览独立读取 App 的玻璃开关。
        previewContent
            .optionalLiquidGlass(
                in: RoundedRectangle(cornerRadius: 22, style: .continuous),
                fallback: Color(uiColor: .secondarySystemBackground)
            )
            .environment(\.isInsideLiquidGlassSurface, false)
    }

    private var previewContent: some View
    {
        VStack(spacing: 0) { previewRows }
    }

    @ViewBuilder
    private var previewRows: some View
    {
        HStack(spacing: 16)
        {
            VStack(alignment: .center, spacing: 6)
            {
                Text("第 \(week) 周")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                Text(CurriculumClassSchedule.periodText(
                    start: course.start,
                    end: course.endPeriod
                ))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(weekdays[course.day - 1])
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .frame(width: 72)
            .padding(.vertical, 4)

            Rectangle()
                .fill(Color.secondary.opacity(0.25))
                .frame(width: 1)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8)
            {
                let shortName = course.shortName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                Text(shortName.isEmpty ? course.name : shortName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                if !shortName.isEmpty
                {
                    Text(course.name)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                if let room = course.room, !room.isEmpty
                {
                    Label(room, systemImage: "location.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                if let teacher = course.teacher, !teacher.isEmpty
                {
                    Label(teacher, systemImage: "person.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                if let assessmentMethod = course.assessmentMethod,
                   !assessmentMethod.isEmpty
                {
                    Label(assessmentMethod, systemImage: "checkmark.seal.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                if course.isManual
                {
                    Label("手动添加", systemImage: "hand.tap.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.blue.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(width: 320)

        // 被压住的冲突课程列表
        if !conflicts.isEmpty
        {
            let weekdays = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]

            ForEach(conflicts, id: \.id)
            { c in
                Divider().padding(.horizontal, 20)

                HStack(spacing: 16)
                {
                    VStack(alignment: .center, spacing: 6)
                    {
                        Text("第 \(week) 周")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                        Text(CurriculumClassSchedule.periodText(
                            start: c.start,
                            end: c.endPeriod
                        ))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text(weekdays[c.day - 1])
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 72)
                    .padding(.vertical, 4)

                    Rectangle()
                        .fill(Color.secondary.opacity(0.25))
                        .frame(width: 1)
                        .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 8)
                    {
                        let shortName = c.shortName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                        Label("同时段其他课程", systemImage: "square.on.square")
                            .font(.system(size: 12))
                            .foregroundColor(.orange.opacity(0.8))
                        Text(shortName.isEmpty ? c.name : shortName)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        if !shortName.isEmpty
                        {
                            Text(c.name)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        if let room = c.room, !room.isEmpty
                        {
                            Label(room, systemImage: "location.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        if let teacher = c.teacher, !teacher.isEmpty
                        {
                            Label(teacher, systemImage: "person.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }

                        if let assessmentMethod = c.assessmentMethod,
                           !assessmentMethod.isEmpty
                        {
                            Label(assessmentMethod, systemImage: "checkmark.seal.fill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }

                        if c.isManual
                        {
                            Label("手动添加", systemImage: "hand.tap.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.blue.opacity(0.8))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(width: 320)
            }
        }
    }
}
struct TimeCurriculumView: View
{
    let fontScale: Double
    let visiblePeriods: [Int]
    @AppStorage(PreferenceKey.enableLiquidGlassEffect) private var enableLiquidGlassEffect = false

    init(
        fontScale: Double = 1.0,
        visiblePeriods: [Int] = CurriculumClassSchedule.displayOrder
    )
    {
        self.fontScale = fontScale
        self.visiblePeriods = visiblePeriods
    }

    @State private var now = Date()
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    /// 预备铃只影响左侧高亮的开始时间；正式起止时间统一来自 CurriculumClassSchedule。
    private static let displayStartTimes: [Int: String] = [
        1: "7:30", 2: "8:45", 3: "9:40", 4: "10:45",
        5: "14:00", 6: "15:15", 7: "16:10", 8: "17:15",
        9: "18:30", 10: "19:45", 11: "20:35", 12: "21:25",
    ]

    private var classPeriods: [ClassPeriod]
    {
        visiblePeriods.compactMap
        { number in
            guard let period = CurriculumClassSchedule.period(number: number)
            else { return nil }

            let startTime = Self.timeText(hour: period.startHour, minute: period.startMinute)
            return ClassPeriod(
                id: number,
                periodNumber: number,
                title: CurriculumClassSchedule.timeAxisTitle(for: number),
                displayStartTime: Self.displayStartTimes[number] ?? startTime,
                startTime: startTime,
                endTime: Self.timeText(hour: period.endHour, minute: period.endMinute)
            )
        }
    }

    private static func timeText(hour: Int, minute: Int) -> String
    {
        String(format: "%d:%02d", hour, minute)
    }

    private var currentPeriodNumber: Int?
    {
        periodNumber(for: now)
    }

    private func periodNumber(for date: Date) -> Int?
    {
        let c = Calendar.current
        let hour = c.component(.hour, from: date)
        let minute = c.component(.minute, from: date)
        let current = hour * 60 + minute

        for period in classPeriods
        {
            guard let displayStart = minutes(from: period.displayStartTime),
                  let end = minutes(from: period.endTime)
            else
            {
                continue
            }

            if current >= displayStart && current < end
            {
                return period.periodNumber
            }
        }
        return nil
    }

    private func minutes(from time: String) -> Int?
    {
        let parts = time.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1])
        else
        {
            return nil
        }
        return hour * 60 + minute
    }

    var body: some View
    {
        VStack(spacing: 0)
        {
            ForEach(classPeriods)
            { period in
                periodRow(period)
            }
        }
        .optionalLiquidGlass(
            enabled: enableLiquidGlassEffect,
            in: Capsule(),
            fallback: Color(.secondarySystemBackground).opacity(0.85)
        )
        .onReceive(timer)
        { input in
            now = input
        }
    }

    @ViewBuilder
    private func periodRow(_ period: ClassPeriod) -> some View
    {
        let isCurrent = currentPeriodNumber == period.periodNumber
        let scale = curriculumDisplayScale(fontScale)

        VStack(spacing: 2 * scale)
        {
            Text(period.title)
                .font(.system(
                    size: (CurriculumClassSchedule.isExtraPeriod(period.periodNumber)
                        ? CurriculumTypography.extraPeriodTitle
                        : CurriculumTypography.periodTitle) * scale,
                    weight: isCurrent ? .bold : .medium,
                    design: .rounded
                ))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundColor(isCurrent ? .white : .secondary)
            Text(period.startTime)
                .font(.system(size: CurriculumTypography.periodTime * scale, weight: .regular, design: .rounded))
                .foregroundColor(isCurrent ? .white : .secondary)
            Text(period.endTime)
                .font(.system(size: CurriculumTypography.periodTime * scale, weight: .regular, design: .rounded))
                .foregroundColor(isCurrent ? .white : .secondary)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: curriculumCellHeight(for: fontScale),
            maxHeight: curriculumCellHeight(for: fontScale)
        )
        .padding(.horizontal, 2)
        .padding(.vertical, 1)
        .appTextOpacity()
        // 当前节与整条时间轴共用 Capsule 轮廓，首节和末节不会出现直角边。
        // 状态颜色通过系统 tint 提供，玻璃浓淡仍跟随系统。
        .background
        {
            if isCurrent
            {
                Color.clear
                    .optionalLiquidGlass(
                        enabled: enableLiquidGlassEffect,
                        allowsNesting: true,
                        in: Capsule(),
                        tint: appActionBlue,
                        fallback: appActionBlue
                    )
            }
            else
            {
                Capsule().fill(Color.clear)
            }
        }
    }
}

#Preview
{
    CurriculumView()
        .environmentObject(userInfo())
        .environmentObject(IAPStore.preview(hasActiveSubscription: true))
}
