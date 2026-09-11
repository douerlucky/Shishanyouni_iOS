//
//  PersonalScheduleWidgetSync.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/9/11.
//

import Foundation
import WidgetKit

/// 把 App 的日程与校历转换成 Widget 能独立读取的 `WidgetScheduleItem` 列表。
///
/// 这个文件只属于主 App Target：它了解 Event 的重复规则、完成状态和校历模型，
/// 但不把这些业务对象暴露给 Widget Extension。
enum PersonalScheduleWidgetSync
{
    private static let lookbackDays = 1
    // 即使用户一段时间没有打开 App，Widget 仍有足够的候选数据可自行切换。
    private static let futureDays = 90
    private static let maximumItemCount = 200

    /// 在 App 成功保存日程或校历后调用；写入 App Group 后主动请求 Widget 刷新。
    static func sync(now: Date = .now)
    {
        let calendar = Calendar.current //取得当前设备的日历和时区。
        let items = makeItems(
            events: EventStore.shared.loadEvents(), //读取用户自己创建的日程
            schoolCalendarEvents: SchoolCalendarStore.shared.loadEvents(), //读取校历
            now: now,
            calendar: calendar
        )

        PersonalScheduleWidgetShared.save(items)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetAppGroup.Kind.personalSchedule)
    }

    /// 独立出来方便后续给日期边界写单元测试，也让 `sync()` 只负责 I/O。
    static func makeItems(
        events: [Event],
        schoolCalendarEvents: [SchoolCalendarEvent],
        now: Date,
        calendar: Calendar = .current
    ) -> [WidgetScheduleItem]
    {
        let today = calendar.startOfDay(for: now)
        let rangeStart = calendar.date(byAdding: .day, value: -lookbackDays, to: today) ?? today
        // `Event.instances(in:)` 接收闭区间。减去一秒后，窗口包含第 90 天的
        // 全天，而不会意外把第 91 天 00:00 的事件也算进来。
        let dayAfterWindow = calendar.date(byAdding: .day, value: futureDays + 1, to: today) ?? today
        let rangeEnd = calendar.date(byAdding: .second, value: -1, to: dayAfterWindow) ?? dayAfterWindow

        let personalScheduleItems = events.flatMap
        {
            personalItems(for: $0, in: rangeStart...rangeEnd, now: now, calendar: calendar)
        }

        let schoolItems = schoolCalendarEvents.compactMap
        {
            schoolCalendarItem(for: $0, now: now, calendar: calendar)
        }

        let items = (personalScheduleItems + schoolItems)
            .filter { PersonalScheduleWidgetShared.isActiveOrUpcoming($0, at: now, calendar: calendar) }
            .sorted { lhs, rhs in
                let lhsIsActive = isActive(lhs, at: now)
                let rhsIsActive = isActive(rhs, at: now)

                if lhsIsActive != rhsIsActive { return lhsIsActive }
                if lhs.startDate != rhs.startDate { return lhs.startDate < rhs.startDate }
                return lhs.id < rhs.id
            }

        return Array(items.prefix(maximumItemCount))
    }

    private static func personalItems(
        for event: Event,
        in dateRange: ClosedRange<Date>,
        now: Date,
        calendar: Calendar
    ) -> [WidgetScheduleItem]
    {
        // 防御历史异常数据，避免 repeat interval 为 0 时现有展开逻辑陷入循环。
        if let repeatRule = event.repeatRule, repeatRule.interval <= 0
        {
            return []
        }

        return event.instances(in: dateRange).compactMap
        {
            occurrence in
            guard !occurrence.isCompleted,
                  !EventStore.shared.isCompleted(eventId: occurrence.id, date: occurrence.date)
            else
            {
                return nil
            }

            return personalItem(for: occurrence, now: now, calendar: calendar)
        }
    }

    private static func personalItem(
        for occurrence: Event,
        now: Date,
        calendar: Calendar
    ) -> WidgetScheduleItem?
    {
        let occurrenceDay = calendar.startOfDay(for: occurrence.date)
        let identifier = "personal-\(occurrence.id.uuidString)-\(dayIdentifier(for: occurrenceDay, calendar: calendar))"

        // 快速新增的待办没有 startTime；即使旧数据的 isAllDay 为 false，
        // 也应按日期型（全天）事项处理，不能把它误判成当天 00:00 已过期。
        if occurrence.isAllDay || occurrence.startTime == nil
        {
            guard let endDate = calendar.date(byAdding: .day, value: 1, to: occurrenceDay) else { return nil }
            let item = WidgetScheduleItem(
                id: identifier,
                title: occurrence.title,
                startDate: occurrenceDay,
                endDate: endDate,
                location: occurrence.location,
                detail: occurrence.note,
                source: .personalSchedule,
                isAllDay: true
            )
            return PersonalScheduleWidgetShared.isActiveOrUpcoming(item, at: now, calendar: calendar) ? item : nil
        }

        let startDate = occurrence.startTime.map { date(on: occurrenceDay, using: $0, calendar: calendar) }
            ?? occurrenceDay
        var endDate = occurrence.endTime.map { date(on: occurrenceDay, using: $0, calendar: calendar) }

        // 编辑器允许 23:00 → 01:00；结束早于开始时表示事件跨到次日。
        if let currentEndDate = endDate, currentEndDate <= startDate
        {
            endDate = calendar.date(byAdding: .day, value: 1, to: currentEndDate)
        }

        let item = WidgetScheduleItem(
            id: identifier,
            title: occurrence.title,
            startDate: startDate,
            endDate: endDate,
            location: occurrence.location,
            detail: occurrence.note,
            source: .personalSchedule,
            isAllDay: false
        )
        return PersonalScheduleWidgetShared.isActiveOrUpcoming(item, at: now, calendar: calendar) ? item : nil
    }

    private static func schoolCalendarItem(
        for event: SchoolCalendarEvent,
        now: Date,
        calendar: Calendar
    ) -> WidgetScheduleItem?
    {
        let startDate = calendar.startOfDay(for: event.startDate)
        let inclusiveEndDate = calendar.startOfDay(for: event.endDate ?? event.startDate)
        guard let exclusiveEndDate = calendar.date(byAdding: .day, value: 1, to: inclusiveEndDate) else
        {
            return nil
        }

        let item = WidgetScheduleItem(
            id: "school-\(event.id.uuidString)",
            title: event.title,
            startDate: startDate,
            endDate: exclusiveEndDate,
            location: nil,
            detail: event.description ?? event.type.rawValue,
            source: .schoolCalendar,
            isAllDay: true
        )
        return PersonalScheduleWidgetShared.isActiveOrUpcoming(item, at: now, calendar: calendar) ? item : nil
    }

    /// 将 Event 分离存储的“日期”与“时刻”合并成真实的绝对时间。
    private static func date(on day: Date, using time: Date, calendar: Calendar) -> Date
    {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second
        return calendar.date(from: components) ?? day
    }

    private static func dayIdentifier(for date: Date, calendar: Calendar) -> String
    {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    /// 同步器生成的事项都有明确的排他结束时间，因此这里不需要猜测默认时长。
    private static func isActive(_ item: WidgetScheduleItem, at date: Date) -> Bool
    {
        guard let endDate = item.endDate else { return false }
        return item.startDate <= date && date < endDate
    }
}
