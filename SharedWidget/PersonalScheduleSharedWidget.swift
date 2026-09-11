//
//  PersonalScheduleSharedWidget.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/9/11.
//

import Foundation

/// Widget 只识别两类来源；原始的 Event / SchoolCalendarEvent 不跨 Target 传递。
enum WidgetScheduleSource: String, Codable, Equatable
{
    case personalSchedule
    case schoolCalendar

    var displayName: String
    {
        switch self
        {
        case .personalSchedule: return "日程"
        case .schoolCalendar: return "校历"
        }
    }
}

/// App 写给日程 Widget 的单条展示数据。
struct WidgetScheduleItem: Codable, Identifiable, Equatable
{
    let id: String
    let title: String //标题
    let startDate: Date //开始时间
    let endDate: Date? //结束时间
    let location: String? //地点
    let detail: String? //备注
    let source: WidgetScheduleSource //日程还是校历
    let isAllDay: Bool //是否全天
}

/// 日程 Widget 的 App Group 存储与展示选择逻辑。
///
/// 这个类型不 import WidgetKit，因此两个 Target 都可以安全使用；
/// 调用 `WidgetCenter.reloadTimelines` 的职责留给 App 侧同步器。
enum PersonalScheduleWidgetShared
{
    static func save(_ items: [WidgetScheduleItem])
    {
        guard let data = try? JSONEncoder().encode(items) else { return }
        WidgetAppGroup.defaults?.set(data, forKey: WidgetAppGroup.Key.personalScheduleItems)
    }

    static func load() -> [WidgetScheduleItem]?
    {
        guard let data = WidgetAppGroup.defaults?.data(forKey: WidgetAppGroup.Key.personalScheduleItems) else
        {
            return nil
        }
        return try? JSONDecoder().decode([WidgetScheduleItem].self, from: data)
    }

    static func clear()
    {
        WidgetAppGroup.defaults?.removeObject(forKey: WidgetAppGroup.Key.personalScheduleItems)
    }

    /// 当前应显示的下一条事项。
    ///
    /// 全天事项（例如校历、全天待办）优先级始终最低：只要候选中存在任意
    /// 有具体时刻的日程，就显示定时日程；只有没有定时日程时才回退显示全天事项。
    /// 同类事项中，正在进行的优先于未来事项，再按开始时间排序。
    static func nextItem(at date: Date = .now) -> WidgetScheduleItem?
    {
        guard let items = load() else { return nil }
        let calendar = Calendar.current
        let candidates = items.filter { isActiveOrUpcoming($0, at: date, calendar: calendar) }

        return candidates.min
        {
            // 全天事项不能抢占任何定时日程，即使自身正在进行也一样。
            if $0.isAllDay != $1.isAllDay { return !$0.isAllDay }

            let lhsIsActive = isActive($0, at: date, calendar: calendar)
            let rhsIsActive = isActive($1, at: date, calendar: calendar)

            if lhsIsActive != rhsIsActive { return lhsIsActive }
            if $0.startDate != $1.startDate { return $0.startDate < $1.startDate }
            return $0.id < $1.id //返回最早开会的
        }
    }

    /// App 同步器与 Widget Provider 共用同一套过期判定，避免旧事项列表显示过期事项。
    static func isActiveOrUpcoming(
        _ item: WidgetScheduleItem,
        at date: Date,
        calendar: Calendar = .current
    ) -> Bool
    {
        if item.isAllDay
        {
            let startDay = calendar.startOfDay(for: item.startDate)
            let endDate = item.endDate
                ?? calendar.date(byAdding: .day, value: 1, to: startDay)
                ?? startDay
            return endDate > date
        }

        // 没有 endDate 的非全天事项是一个时间点，到点后不再作为“下一条”。
        return (item.endDate ?? item.startDate) > date
    }

    /// 下一次值得请求系统刷新时间线的时间点。
    static func nextRefreshDate(after date: Date = .now) -> Date
    {
        guard let item = nextItem(at: date) else
        {
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: date))
            return tomorrow ?? date.addingTimeInterval(24 * 60 * 60)
        }

        if item.startDate > date
        {
            return item.startDate
        }

        if item.isAllDay
        {
            return item.endDate ?? date.addingTimeInterval(60 * 60)
        }

        if let endDate = item.endDate, endDate > date
        {
            return endDate
        }

        return date.addingTimeInterval(60 * 60)
    }

    private static func isActive(_ item: WidgetScheduleItem, at date: Date, calendar: Calendar) -> Bool
    {
        if item.isAllDay
        {
            let startDay = calendar.startOfDay(for: item.startDate)
            let endDate = item.endDate
                ?? calendar.date(byAdding: .day, value: 1, to: startDay)
                ?? startDay
            return item.startDate <= date && date < endDate
        }

        guard let endDate = item.endDate else { return false }
        return item.startDate <= date && date < endDate
    }
}
