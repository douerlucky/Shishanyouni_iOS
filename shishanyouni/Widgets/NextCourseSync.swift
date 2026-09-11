//
//  NextCourseSync.swift
//  shishanyouni
//
//  主 App 到桌面／锁屏“下节课”组件的同步器。
//

import Foundation
import WidgetKit

/// 将 App 的完整 `Course` 转换成桌面／锁屏“下节课”组件所需的绝对时间课程实例。
///
/// 同步 90 天候选数据，而 Widget 只展示未来 2 天。这样用户不开 App 时，
/// 某节更晚的课进入 2 天展示窗口后，Widget 仍能自己切换出来。
enum NextCourseSync
{
    private static let futureDays = 90
    private static let maximumItemCount = 300

    /// 当前学校课表的实际上课时间。
    /// 与 `CurriculumNotificationManager` 使用的节次时间保持一致；`displayStartTime`
    /// （如 7:30 预备铃）不作为课程开始，避免把尚未正式上课的课当成已开始。
    private static let classPeriods: [(number: Int, start: (hour: Int, minute: Int), end: (hour: Int, minute: Int))] = [
        (1, (8, 0), (8, 45)),
        (2, (8, 55), (9, 40)),
        (3, (10, 0), (10, 45)),
        (4, (10, 55), (11, 40)),
        (5, (14, 30), (15, 15)),
        (6, (15, 25), (16, 10)),
        (7, (16, 30), (17, 15)),
        (8, (17, 25), (18, 10)),
        (9, (19, 0), (19, 45)),
        (10, (19, 50), (20, 35)),
        (11, (20, 40), (21, 25)),
        (12, (21, 30), (22, 15)),
    ]

    /// 课表导入、编辑、删除，以及 App 回到前台时调用。
    static func sync(
        courses: [Course]? = nil,
        semesterStart: Date? = nil,
        now: Date = .now
    )
    {
        let currentCourses = courses ?? CurriculumStore.shared.loadCourses()
        let currentSemesterStart = semesterStart ?? CurriculumStore.shared.loadSemesterStartDate()

        guard let currentSemesterStart else
        {
            clear()
            return
        }

        let items = makeItems(
            courses: currentCourses,
            semesterStart: currentSemesterStart,
            now: now
        )
        NextCourseWidgetShared.save(items)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetAppGroup.Kind.nextCourse)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetAppGroup.Kind.screenlockNextCourse)
    }

    static func clear()
    {
        NextCourseWidgetShared.clear()
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetAppGroup.Kind.nextCourse)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetAppGroup.Kind.screenlockNextCourse)
    }

    /// 独立为纯转换函数，便于用固定日期验证周次、两天窗口和节次边界。
    static func makeItems(
        courses: [Course],
        semesterStart: Date,
        now: Date,
        calendar: Calendar = .current
    ) -> [WidgetNextCourse]
    {
        let startOfToday = calendar.startOfDay(for: now)
        let lastDay = calendar.date(byAdding: .day, value: futureDays, to: startOfToday) ?? startOfToday
        let dayCount = max(calendar.dateComponents([.day], from: startOfToday, to: lastDay).day ?? 0, 0)

        var items: [WidgetNextCourse] = []
        for offset in 0 ... dayCount
        {
            guard let candidateDay = calendar.date(byAdding: .day, value: offset, to: startOfToday) else
            {
                continue
            }

            let weekday = normalizedWeekday(for: candidateDay, calendar: calendar)
            let week = academicWeek(for: candidateDay, semesterStart: semesterStart, calendar: calendar)

            for course in courses
            {
                guard course.day == weekday,
                      course.weekList.contains(week),
                      let startPeriod = classPeriods.first(where: { $0.number == course.start }),
                      let endPeriod = classPeriods.first(where: { $0.number == course.endPeriod }),
                      let startDate = date(on: candidateDay, at: startPeriod.start, calendar: calendar),
                      let endDate = date(on: candidateDay, at: endPeriod.end, calendar: calendar),
                      endDate > startDate
                else
                {
                    continue
                }

                items.append(
                    WidgetNextCourse(
                        id: "course-\(course.id)-\(startDate.timeIntervalSince1970)",
                        name: course.name,
                        startDate: startDate,
                        endDate: endDate,
                        room: course.room,
                        teacher: course.teacher,
                        periodText: periodText(start: course.start, end: course.endPeriod)
                    )
                )
            }
        }

        return Array(
            items
                .filter { $0.endDate > now }
                .sorted
                {
                    if $0.startDate != $1.startDate { return $0.startDate < $1.startDate }
                    return $0.id < $1.id
                }
                .prefix(maximumItemCount)
        )
    }

    private static func date(
        on day: Date,
        at time: (hour: Int, minute: Int),
        calendar: Calendar
    ) -> Date?
    {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = time.hour
        components.minute = time.minute
        return calendar.date(from: components)
    }

    private static func academicWeek(for date: Date, semesterStart: Date, calendar: Calendar) -> Int
    {
        var mondayCalendar = calendar
        mondayCalendar.firstWeekday = 2
        let startComponents = mondayCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: semesterStart)
        let dateComponents = mondayCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)

        guard let semesterMonday = mondayCalendar.date(from: startComponents),
              let currentMonday = mondayCalendar.date(from: dateComponents)
        else
        {
            return 1
        }

        let difference = mondayCalendar.dateComponents([.weekOfYear], from: semesterMonday, to: currentMonday)
        return max((difference.weekOfYear ?? 0) + 1, 1)
    }

    private static func normalizedWeekday(for date: Date, calendar: Calendar) -> Int
    {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 ? 7 : weekday - 1
    }

    private static func periodText(start: Int, end: Int) -> String
    {
        start == end ? "第\(start)节" : "第\(start)-\(end)节"
    }
}
