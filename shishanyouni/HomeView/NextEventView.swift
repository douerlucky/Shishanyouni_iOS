//
//  NextEventView.swift
//  shishanyouni
//
//  首页「下一个事件」横向滑动卡片组件。
//  聚合四种事件源：课程、个人日程、校历、考试，按时间排序展示接下来3天内的事件。
//

import SwiftUI
import Foundation

extension Notification.Name
{
    static let homeNextEventsDidChange = Notification.Name("homeNextEventsDidChange")
}

// MARK: - 统一事件模型

struct NextEventItem: Identifiable
{
    let id: String
    /// 事件标题（课程名、日程标题、考试科目）
    let title: String
    /// 地点/教室
    let subtitle: String?
    /// 额外信息（如课程教师）
    let detail: String?
    /// 事件发生时间（用于排序）
    let date: Date
    /// 事件类型
    let type: NextEventType
}

enum NextEventType: String
{
    case course = "课程"
    case userEvent = "日程"
    case schoolCalendar = "校历"
    case exam = "考试"

    var icon: String
    {
        switch self
        {
        case .course: return "book.fill"
        case .userEvent: return "checklist"
        case .schoolCalendar: return "calendar"
        case .exam: return "pencil.and.list.clipboard"
        }
    }

    var color: Color
    {
        switch self
        {
        case .course: return .blue
        case .userEvent: return .orange
        case .schoolCalendar: return .green
        case .exam: return .red
        }
    }
}

// MARK: - ViewModel

@MainActor
class NextEventViewModel: ObservableObject
{
    @Published var nextEvents: [NextEventItem] = []
    @Published var isLoading = false

    private let calendar = Calendar.current

    func refresh()
    {
        isLoading = true
        nextEvents = buildUpcomingEvents()
        isLoading = false
    }

    private func buildUpcomingEvents() -> [NextEventItem]
    {
        let now = Date()
        guard let threeDaysLater = calendar.date(byAdding: .day, value: 3, to: now) else { return [] }

        var items: [NextEventItem] = []

        // ——— 1. 课表事件 ———
        let courses = CurriculumStore.shared.loadCourses()
        let semesterStart = loadSemesterStart()
        items += courseEvents(from: courses, semesterStart: semesterStart, now: now, limit: threeDaysLater)

        // ——— 2. 个人日程 ———
        let events = EventStore.shared.loadEvents()
        items += userEvents(from: events, now: now, limit: threeDaysLater)

        // ——— 3. 校历 ———
        let schoolEvents = SchoolCalendarStore.shared.loadEvents()
        items += schoolCalendarEvents(from: schoolEvents, now: now, limit: threeDaysLater)

        // ——— 4. 考试（已有缓存数据） ———
        let exams = ExamStore.shared.loadLatestExams()
        items += examEvents(from: exams, now: now, limit: threeDaysLater)

        // 排序：按时间升序
        items.sort { $0.date < $1.date }
        return items
    }

    // MARK: - 课表

    private func courseEvents(from courses: [Course], semesterStart: Date, now: Date, limit: Date) -> [NextEventItem]
    {
        var result: [NextEventItem] = []
        let classPeriods: [(period: Int, startHour: Int, startMin: Int)] = [
            (1, 8, 0), (2, 9, 0), (3, 10, 0), (4, 10, 55),
            (5, 14, 30), (6, 15, 15), (7, 16, 30), (8, 17, 25),
            (9, 19, 0), (10, 19, 50), (11, 20, 40), (12, 21, 30),
        ]

        let scanStart = calendar.startOfDay(for: now)
        let scanEnd = calendar.startOfDay(for: limit)
        let totalDays = max(calendar.dateComponents([.day], from: scanStart, to: scanEnd).day ?? 0, 0)

        for offset in 0 ... totalDays
        {
            guard let candidateDay = calendar.date(byAdding: .day, value: offset, to: scanStart) else { continue }
            let weekday = normalizedWeekday(for: candidateDay)
            let week = academicWeek(for: candidateDay, semesterStart: semesterStart)

            for course in courses
            {
                guard course.day == weekday else { continue }
                guard course.weekList.contains(week) else { continue }
                guard let periodInfo = classPeriods.first(where: { $0.period == course.start }) else { continue }

                var comps = calendar.dateComponents([.year, .month, .day], from: candidateDay)
                comps.hour = periodInfo.startHour
                comps.minute = periodInfo.startMin
                guard let classDateTime = calendar.date(from: comps) else { continue }
                guard classDateTime >= now && classDateTime <= limit else { continue }

                result.append(NextEventItem(
                    id: "course_\(course.id)_\(classDateTime.timeIntervalSince1970)",
                    title: course.name,
                    subtitle: course.room,
                    detail: course.teacher,
                    date: classDateTime,
                    type: .course
                ))
            }
        }

        return result
    }

    // MARK: - 个人日程

    private func userEvents(from events: [Event], now: Date, limit: Date) -> [NextEventItem]
    {
        var result: [NextEventItem] = []
        let instanceRange = calendar.startOfDay(for: now) ... limit

        for event in events
        {
            guard !event.isCompleted else { continue }

            // 全部实例（含重复规则）
            let instances = event.instances(in: instanceRange)

            for instance in instances
            {
                guard !instance.isCompleted else { continue }
                let eventDate: Date
                if let start = instance.startTime
                {
                    var comps = calendar.dateComponents([.year, .month, .day], from: instance.date)
                    let timeComps = calendar.dateComponents([.hour, .minute], from: start)
                    comps.hour = timeComps.hour
                    comps.minute = timeComps.minute
                    eventDate = calendar.date(from: comps) ?? instance.date
                }
                else
                {
                    eventDate = instance.date
                }

                guard eventDate >= now && eventDate <= limit else { continue }

                result.append(NextEventItem(
                    id: "event_\(instance.id)_\(eventDate.timeIntervalSince1970)",
                    title: instance.title,
                    subtitle: instance.location,
                    detail: nil,
                    date: eventDate,
                    type: .userEvent
                ))
            }
        }
        return result
    }

    // MARK: - 校历

    private func schoolCalendarEvents(from events: [SchoolCalendarEvent], now: Date, limit: Date) -> [NextEventItem]
    {
        var result: [NextEventItem] = []

        for event in events
        {
            guard event.startDate >= now && event.startDate <= limit else { continue }

            result.append(NextEventItem(
                id: "school_\(event.id)",
                title: event.title,
                subtitle: event.description ?? event.type.rawValue,
                detail: nil,
                date: event.startDate,
                type: .schoolCalendar
            ))
        }
        return result
    }

    // MARK: - 考试

    private func examEvents(from exams: [Exam], now: Date, limit: Date) -> [NextEventItem]
    {
        var result: [NextEventItem] = []

        for exam in exams
        {
            guard let examDate = exam.examStartDate else { continue }
            guard examDate >= now && examDate <= limit else { continue }

            result.append(NextEventItem(
                id: "exam_\(exam.id)",
                title: exam.kcmc,
                subtitle: exam.cdmc,
                detail: nil,
                date: examDate,
                type: .exam
            ))
        }
        return result
    }

    // MARK: - 辅助

    private func loadSemesterStart() -> Date
    {
        if let semesterStart = CurriculumStore.shared.loadSemesterStartDate()
        {
            return semesterStart
        }
        var comps = DateComponents()
        comps.year = 2026; comps.month = 3; comps.day = 2
        return Calendar.current.date(from: comps) ?? Date()
    }

    private func academicWeek(for date: Date, semesterStart: Date) -> Int
    {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let startComps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: semesterStart)
        let targetComps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        guard let startMonday = cal.date(from: startComps),
              let currentMonday = cal.date(from: targetComps) else { return 1 }
        let diff = cal.dateComponents([.weekOfYear], from: startMonday, to: currentMonday)
        return (diff.weekOfYear ?? 0) + 1
    }

    private func normalizedWeekday(for date: Date) -> Int
    {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 ? 7 : weekday - 1
    }

    private func formatCoursePeriods(start: Int, step: Int) -> String
    {
        let end = start + step - 1
        return start == end ? "第\(start)节课" : "第\(start)-\(end)节课"
    }
}

// MARK: - 时间格式化

private func formatEventTime(_ date: Date) -> String
{
    let cal = Calendar.current

    if cal.isDateInToday(date) { return "今天" + formatTimeOnly(date) }
    if isTomorrow(date) { return "明天" + formatTimeOnly(date) }
    if isDayAfterTomorrow(date) { return "后天" + formatTimeOnly(date) }

    let fmt = DateFormatter()
    fmt.locale = Locale(identifier: "zh_CN")
    fmt.dateFormat = "M月d日 HH:mm"
    return fmt.string(from: date)
}

private func formatTimeOnly(_ date: Date) -> String
{
    let fmt = DateFormatter()
    fmt.dateFormat = " HH:mm"
    return fmt.string(from: date)
}

private func isTomorrow(_ date: Date) -> Bool
{
    Calendar.current.isDate(Date().addingTimeInterval(86400), inSameDayAs: date)
}

private func isDayAfterTomorrow(_ date: Date) -> Bool
{
    Calendar.current.isDate(Date().addingTimeInterval(172800), inSameDayAs: date)
}

// MARK: - View

struct NextEventView: View
{
    @AppStorage("scheduleContentOpacity") private var scheduleContentOpacity: Double = 1.0
    @AppStorage("enableLiquidGlassEffect") private var enableLiquidGlassEffect: Bool = false
    @StateObject private var vm = NextEventViewModel()

    private var cardOpacity: Double
    {
        max(scheduleContentOpacity, 0.92)
    }

    var body: some View
    {
        GeometryReader { proxy in
            let containerWidth = proxy.size.width
            let cardWidth: CGFloat = 290               // 卡片固定宽度，比屏幕窄
            let firstCardLeading = (containerWidth - cardWidth) / 2  // 第一张卡片居中

            Group
            {
                if vm.nextEvents.isEmpty
                {
                    emptyCard(width: cardWidth)
                        .padding(.leading, firstCardLeading)
                }
                else
                {
                    ScrollView(.horizontal, showsIndicators: false)
                    {
                        LazyHStack(spacing: 12)
                        {
                            ForEach(vm.nextEvents) { event in
                                eventCard(event)
                                    .frame(width: cardWidth)
                            }
                        }
                        .padding(.leading, firstCardLeading)
                        .padding(.trailing, 16)  // 右侧露出下一张卡片边缘
                    }
                }
            }
        }
        .frame(height: 132)
        .onAppear { vm.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .homeNextEventsDidChange)) { _ in
            vm.refresh()
        }
    }

    private func emptyCard(width: CGFloat) -> some View
    {
        HStack(spacing: 14)
        {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 26))
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 4)
            {
                Text("接下来 3 天暂无安排")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: width, height: 120, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.82))
        )
        .optionalLiquidGlass(enabled: enableLiquidGlassEffect, cornerRadius: 20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(.separator).opacity(0.12), lineWidth: 1)
        )
        .opacity(cardOpacity)
    }

    @ViewBuilder
    private func eventCard(_ event: NextEventItem) -> some View
    {
        HStack(spacing: 14)
        {
            // 左侧：图标 + 类型标签
            VStack(spacing: 6)
            {
                ZStack
                {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(event.type.color.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: event.type.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(event.type.color)
                }

                Text(event.type.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(event.type.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(event.type.color.opacity(0.12))
                    .clipShape(Capsule())
            }

            // 中间文字
            VStack(alignment: .leading, spacing: 3)
            {
                Text(event.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)

                if let sub = event.subtitle, !sub.isEmpty
                {
                    Label(sub, systemImage: "location.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if let detail = event.detail, !detail.isEmpty
                {
                    Label(detail, systemImage: "person.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Text(formatEventTime(event.date))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(event.type.color.opacity(0.8))
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 132)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(event.type.color.opacity(0.06))
                )
        )
        .optionalLiquidGlass(enabled: enableLiquidGlassEffect, cornerRadius: 20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(event.type.color.opacity(0.10), lineWidth: 1)
        )
        .opacity(cardOpacity)
    }
}

#Preview
{
    NextEventView()
}
