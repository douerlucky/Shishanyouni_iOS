//
//  CurriculumToSystemCalendar.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/9/11.
//

import EventKit
import Foundation

/// 课表导入系统日历时可能出现的业务错误。
enum CurriculumSystemCalendarError: LocalizedError
{
    case calendarAccessDenied
    case noWritableCalendarSource
    case noUpcomingCourses
    case calendarAlreadyImported(String)
    case noImportedCalendar
    case eventStoreError(String)

    var errorDescription: String?
    {
        switch self
        {
        case .calendarAccessDenied:
            return "没有获得系统日历权限。请在系统设置中允许访问日历后重试。"
        case .noWritableCalendarSource:
            return "没有找到可用于创建课表日历的系统日历账户。"
        case .noUpcomingCourses:
            return "从现在到学期结束没有可导入的课程安排。"
        case let .calendarAlreadyImported(title):
            return "本学期课程已经导入到“\(title)”。如需更新，请先删除旧的课表日历。"
        case .noImportedCalendar:
            return "没有找到由狮山有你创建的课表日历。"
        case let .eventStoreError(message):
            return message
        }
    }
}

/// 一个已经展开到具体日期的课程事件。
/// 这是 EventKit 之前的中间模型，便于独立测试日期计算。
struct CurriculumCalendarEventDraft
{
    let course: Course
    let week: Int
    let classDate: Date
    let startDate: Date
    let endDate: Date
}

/// 只负责课表与系统日历之间的读写。
/// IAP 判断和页面弹窗由 AllCurriculumSetting 负责。
enum CurriculumToSystemCalendar
{
    /// UserDefaults key 的前缀，不是用户在系统日历中看到的标题。
    private static let calendarIdentifierKeyPrefix = "curriculumSystemCalendarIdentifier"

    /// 根据开学日期生成用户可读的专属日历名称。
    /// 例如 2026-08-31 → “狮山有你 · 2026-2027 秋季课表”。
    static func calendarTitle(for semesterStartDate: Date) -> String
    {
        let components = Calendar.current.dateComponents([.year, .month], from: semesterStartDate)
        let year = components.year ?? 2026
        let month = components.month ?? 8
        let isAutumnSemester = month >= 8
        let academicYearStart = isAutumnSemester ? year : year - 1
        let semesterName = isAutumnSemester ? "秋季" : "春季"
        return "狮山有你 · \(academicYearStart)-\(academicYearStart + 1) \(semesterName)课表"
    }

    /// 给每个学期生成稳定的本地存储 key。
    private static func calendarIdentifierKey(for semesterStartDate: Date) -> String
    {
        let components = Calendar.current.dateComponents([.year, .month], from: semesterStartDate)
        let year = components.year ?? 2026
        let month = components.month ?? 8
        let isAutumnSemester = month >= 8
        let academicYearStart = isAutumnSemester ? year : year - 1
        let semesterCode = isAutumnSemester ? "fall" : "spring"
        return "\(calendarIdentifierKeyPrefix).\(academicYearStart)-\(academicYearStart + 1).\(semesterCode)"
    }

    /// 向系统请求读取与写入日历的权限。
    static func requestFullAccess(to store: EKEventStore) async throws -> Bool
    {
        try await withCheckedThrowingContinuation
        { continuation in
            if #available(iOS 17.0, *)
            {
                store.requestFullAccessToEvents
                { granted, error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: granted) }
                }
            }
            else
            {
                store.requestAccess(to: .event)
                { granted, error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: granted) }
                }
            }
        }
    }

    /// 取回当前学期由 App 创建的专属课表日历。
    static func savedCalendar(in store: EKEventStore, semesterStartDate: Date) -> EKCalendar?
    {
        guard let identifier = UserDefaults.standard.string(
            forKey: calendarIdentifierKey(for: semesterStartDate)
        ) else { return nil }
        return store.calendar(withIdentifier: identifier)
    }

    private static func saveCalendarIdentifier(_ identifier: String, semesterStartDate: Date)
    {
        UserDefaults.standard.set(
            identifier,
            forKey: calendarIdentifierKey(for: semesterStartDate)
        )
    }

    private static func clearSavedCalendarIdentifier(semesterStartDate: Date)
    {
        UserDefaults.standard.removeObject(forKey: calendarIdentifierKey(for: semesterStartDate))
    }

    /// 找回已创建的课表日历；第一次使用时创建一个新的专属日历。
    static func createOrGetCalendar(in store: EKEventStore, semesterStartDate: Date) throws -> EKCalendar
    {
        if let savedCalendar = savedCalendar(in: store, semesterStartDate: semesterStartDate)
        {
            return savedCalendar
        }

        guard let source = store.defaultCalendarForNewEvents?.source
            ?? store.calendars(for: .event)
                .first(where: { $0.allowsContentModifications })?.source
        else { throw CurriculumSystemCalendarError.noWritableCalendarSource }

        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = calendarTitle(for: semesterStartDate)
        calendar.source = source

        do { try store.saveCalendar(calendar, commit: true) }
        catch
        {
            throw CurriculumSystemCalendarError.eventStoreError(
                "创建课表日历失败：\(error.localizedDescription)"
            )
        }

        saveCalendarIdentifier(calendar.calendarIdentifier, semesterStartDate: semesterStartDate)
        return calendar
    }

    /// 把所有 Course 展开成每一次真实上课的事件草稿。
    /// now 允许测试传入固定时间；正式使用时默认取当前时间。
    static func eventDrafts(
        for courses: [Course],
        semesterStartDate: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [CurriculumCalendarEventDraft]
    {
        var calendar = calendar
        calendar.firstWeekday = 2

        let startComponents = calendar.dateComponents(
            [.yearForWeekOfYear, .weekOfYear],
            from: semesterStartDate
        )
        guard let firstMonday = calendar.date(from: startComponents) else { return [] }

        var drafts: [CurriculumCalendarEventDraft] = []

        for course in courses
        {
            guard (1 ... 7).contains(course.day) else { continue }

            for week in Set(course.weekList).sorted()
            {
                guard week >= 1,
                      let classDate = calendar.date(
                          byAdding: .day,
                          value: (week - 1) * 7 + (course.day - 1),
                          to: firstMonday
                      ),
                      let dateRange = CurriculumClassSchedule.dateRange(
                          for: course,
                          on: classDate,
                          calendar: calendar
                      ),
                      dateRange.endDate > now
                else { continue }

                drafts.append(
                    CurriculumCalendarEventDraft(
                        course: course,
                        week: week,
                        classDate: classDate,
                        startDate: dateRange.startDate,
                        endDate: dateRange.endDate
                    )
                )
            }
        }

        return drafts.sorted
        {
            if $0.startDate != $1.startDate { return $0.startDate < $1.startDate }
            return $0.course.name.localizedStandardCompare($1.course.name) == .orderedAscending
        }
    }

    /// 请求权限后，将本学期尚未结束的课程写入专属系统日历。
    /// 已经导入过时拒绝再次写入，避免重复事件；如需更新，先删除旧日历。
    static func importCourses(
        in store: EKEventStore,
        courses: [Course],
        semesterStartDate: Date,
        now: Date = Date()
    ) async throws -> Int
    {
        guard try await requestFullAccess(to: store)
        else { throw CurriculumSystemCalendarError.calendarAccessDenied }

        let drafts = eventDrafts(
            for: courses,
            semesterStartDate: semesterStartDate,
            now: now
        )
        guard !drafts.isEmpty else { throw CurriculumSystemCalendarError.noUpcomingCourses }

        if let existingCalendar = savedCalendar(in: store, semesterStartDate: semesterStartDate)
        {
            throw CurriculumSystemCalendarError.calendarAlreadyImported(existingCalendar.title)
        }

        let calendar = try createOrGetCalendar(in: store, semesterStartDate: semesterStartDate)

        do
        {
            for draft in drafts
            {
                let event = EKEvent(eventStore: store)
                event.title = draft.course.name
                event.startDate = draft.startDate
                event.endDate = draft.endDate
                event.calendar = calendar
                event.location = draft.course.room
                event.notes = eventNotes(for: draft)
                event.alarms = []

                do { try store.save(event, span: .thisEvent, commit: false) }
                catch
                {
                    throw CurriculumSystemCalendarError.eventStoreError(
                        "保存“\(draft.course.name)”失败：\(error.localizedDescription)"
                    )
                }
            }

            do { try store.commit() }
            catch
            {
                throw CurriculumSystemCalendarError.eventStoreError(
                    "提交课程日历失败：\(error.localizedDescription)"
                )
            }
        }
        catch
        {
            // 中途失败时删除刚创建的专属日历，避免留下半套课表。
            try? store.removeCalendar(calendar, commit: true)
            clearSavedCalendarIdentifier(semesterStartDate: semesterStartDate)
            throw error
        }

        return drafts.count
    }

    /// 删除当前学期由 App 创建的专属课表日历。
    /// 不检查 IAP，会员到期后仍应允许用户删除自己的数据。
    static func deleteImportedCalendar(
        in store: EKEventStore,
        semesterStartDate: Date
    ) async throws -> String
    {
        guard try await requestFullAccess(to: store)
        else { throw CurriculumSystemCalendarError.calendarAccessDenied }

        guard let calendar = savedCalendar(in: store, semesterStartDate: semesterStartDate)
        else
        {
            clearSavedCalendarIdentifier(semesterStartDate: semesterStartDate)
            throw CurriculumSystemCalendarError.noImportedCalendar
        }

        let title = calendar.title
        do { try store.removeCalendar(calendar, commit: true) }
        catch
        {
            throw CurriculumSystemCalendarError.eventStoreError(
                "删除课表日历失败：\(error.localizedDescription)"
            )
        }

        clearSavedCalendarIdentifier(semesterStartDate: semesterStartDate)
        return title
    }

    private static func eventNotes(for draft: CurriculumCalendarEventDraft) -> String
    {
        var lines = [
            "由狮山有你导入",
            "第\(draft.week)周 · 周\(draft.course.day) · 第\(draft.course.start)-\(draft.course.endPeriod)节"
        ]

        if let teacher = draft.course.teacher,
           !teacher.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            lines.append("教师：\(teacher)")
        }

        return lines.joined(separator: "\n")
    }
}

/// 一节课在一天中的正式起止时间。
struct CurriculumClassPeriod: Equatable
{
    let number: Int
    let startHour: Int
    let startMinute: Int
    let endHour: Int
    let endMinute: Int

    /// 整点开始的课程可省略 startMinute，非整点课程显式传入即可。
    init(
        number: Int,
        startHour: Int,
        startMinute: Int = 0,
        endHour: Int,
        endMinute: Int
    )
    {
        self.number = number
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
    }
}

/// 课表、提醒、系统日历共用的正式节次时间表。
enum CurriculumClassSchedule
{
    static let periods: [CurriculumClassPeriod] =
    [
        .init(number: 1, startHour: 8, endHour: 8, endMinute: 45),
        .init(number: 2, startHour: 8, startMinute: 55, endHour: 9, endMinute: 40),
        .init(number: 3, startHour: 10, endHour: 10, endMinute: 45),
        .init(number: 4, startHour: 10, startMinute: 55, endHour: 11, endMinute: 40),
        .init(number: 5, startHour: 14, startMinute: 30, endHour: 15, endMinute: 15),
        .init(number: 6, startHour: 15, startMinute: 25, endHour: 16, endMinute: 10),
        .init(number: 7, startHour: 16, startMinute: 30, endHour: 17, endMinute: 15),
        .init(number: 8, startHour: 17, startMinute: 25, endHour: 18, endMinute: 10),
        .init(number: 9, startHour: 19, endHour: 19, endMinute: 45),
        .init(number: 10, startHour: 19, startMinute: 50, endHour: 20, endMinute: 35),
        .init(number: 11, startHour: 20, startMinute: 40, endHour: 21, endMinute: 25),
        .init(number: 12, startHour: 21, startMinute: 30, endHour: 22, endMinute: 15),
    ]

    static func period(number: Int) -> CurriculumClassPeriod?
    {
        periods.first { $0.number == number }
    }

    /// 根据某一天和课程的起止节次，算出真实开始、结束时间。
    static func dateRange(
        for course: Course,
        on classDate: Date,
        calendar: Calendar = .current
    ) -> (startDate: Date, endDate: Date)?
    {
        guard let startPeriod = period(number: course.start),
              let endPeriod = period(number: course.endPeriod)
        else { return nil }

        var startComponents = calendar.dateComponents([.year, .month, .day], from: classDate)
        startComponents.hour = startPeriod.startHour
        startComponents.minute = startPeriod.startMinute

        var endComponents = calendar.dateComponents([.year, .month, .day], from: classDate)
        endComponents.hour = endPeriod.endHour
        endComponents.minute = endPeriod.endMinute

        guard let startDate = calendar.date(from: startComponents),
              let endDate = calendar.date(from: endComponents)
        else { return nil }

        return (startDate, endDate)
    }
}
