import SwiftUI
import Foundation

// MARK: - ViewModel

/// 将不同来源的数据规范化为 NextEventItem，并按发生时间排序。
/// 当前读取的数据量很小，刷新同步完成，避免首页出现不必要的异步加载状态。
@MainActor
class NextEventViewModel: ObservableObject
{
    @Published var nextEvents: [NextEventItem] = []
    @Published var isLoading = false

    private let calendar = Calendar.current

    func refresh()
    {
        // 保留 isLoading 是为了未来接入异步数据源；目前四类数据均来自本地存储。
        isLoading = true
        nextEvents = buildUpcomingEvents()
        isLoading = false
    }

    private func buildUpcomingEvents() -> [NextEventItem]
    {
        let now = Date()
        guard let threeDaysLater = calendar.date(byAdding: .day, value: 3, to: now) else { return [] }

        var items: [NextEventItem] = []

        // 每个来源先独立转换，最后统一排序，避免 UI 层知道各业务模型的细节。
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
        // 课表只存“第几周/周几/第几节”，这里扫描未来三天并还原为实际 Date。
        var result: [NextEventItem] = []
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
                guard course.hasScheduledTime, course.day == weekday else { continue }
                guard course.weekList.contains(week) else { continue }
                guard let periodInfo = CurriculumClassSchedule.period(number: course.start) else { continue }

                var comps = calendar.dateComponents([.year, .month, .day], from: candidateDay)
                comps.hour = periodInfo.startHour
                comps.minute = periodInfo.startMinute
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

            // Event.instances 会展开重复规则，首页只需要检查展开后的真实发生时间。
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
            // 校历的多日事件按开始日进入“下一个安排”，不为每天重复生成一张卡片。
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
        return CurriculumClassSchedule.periodText(start: start, end: end) + "课"
    }
}
