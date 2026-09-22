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

/// 中号“近期日程”组件的一张展示快照。
/// 这是内存中的选择结果，不会写入 App Group；App Group 仍只保存原始日程 DTO。
struct PersonalScheduleWidgetPresentation: Equatable
{
    let items: [WidgetScheduleItem]
    let remainingItemCount: Int
}

/// 日程 Widget 的 App Group 存储与展示选择逻辑。
///
/// 这个类型不 import WidgetKit，因此两个 Target 都可以安全使用；
/// 调用 `WidgetCenter.reloadTimelines` 的职责留给 App 侧同步器。
enum PersonalScheduleWidgetShared
{
    /// “近期日程”固定查看从此刻起的七天，不把更久以后的事项计入组件数量。
    private static let presentationWindowDays = 7

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

    /// 选择中号组件要显示的“近期日程”。
    ///
    /// - 固定展示七天窗口中排序最靠前的三条；其余数量只统计同一窗口，文案为“未来一星期内还有 N 条”。
    /// - 用户创建的日程永远优先于校历事项；同一来源内，全天事项排在定时事项后面。
    /// - 组件行会各自显示日期，因此三条可以来自不同日期而不会失去时间语境。
    static func recentPresentation(
        at date: Date = .now,
        maximumVisibleItemCount: Int = 3
    ) -> PersonalScheduleWidgetPresentation?
    {
        guard let items = load() else { return nil }
        let calendar = Calendar.current
        let windowEnd = calendar.date(byAdding: .day, value: presentationWindowDays, to: date)
            ?? date.addingTimeInterval(TimeInterval(presentationWindowDays * 24 * 60 * 60))
        let candidates = items
            .filter
            {
                // 已开始但尚未结束的事项也算“近期”；未来事项则不能晚于七天窗口。
                isActiveOrUpcoming($0, at: date, calendar: calendar) && $0.startDate <= windowEnd
            }
            .sorted { itemComesBefore($0, $1, at: date, calendar: calendar) }

        guard !candidates.isEmpty else { return nil }
        let visibleItems = Array(candidates.prefix(maximumVisibleItemCount))

        return PersonalScheduleWidgetPresentation(
            items: visibleItems,
            remainingItemCount: max(candidates.count - visibleItems.count, 0)
        )
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
        guard let items = load() else
        {
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: date))
            return tomorrow ?? date.addingTimeInterval(24 * 60 * 60)
        }

        // 事项开始、结束或进入未来七天窗口时，都可能改变前三条或剩余数量，取最近的状态切换点。
        let nextTransition = items
            .filter { isActiveOrUpcoming($0, at: date) }
            .flatMap
            { item -> [Date] in
                var dates: [Date] = []
                if item.startDate > date { dates.append(item.startDate) }
                if let endDate = item.endDate, endDate > date { dates.append(endDate) }

                // 例如八天后的事项，会在七天后进入组件的展示窗口；必须提前请求一次新 Timeline。
                if let entersPresentationWindow = Calendar.current.date(
                    byAdding: .day,
                    value: -presentationWindowDays,
                    to: item.startDate
                ), entersPresentationWindow > date
                {
                    dates.append(entersPresentationWindow)
                }
                return dates
            }
            .min()

        if let nextTransition
        {
            return nextTransition
        }

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: date))
        return tomorrow ?? date.addingTimeInterval(24 * 60 * 60)
    }

    private static func itemComesBefore(
        _ lhs: WidgetScheduleItem,
        _ rhs: WidgetScheduleItem,
        at date: Date,
        calendar: Calendar
    ) -> Bool
    {
        // 用户亲自创建的日程永远比学校校历优先，哪怕校历的时间更早。
        if lhs.source != rhs.source { return lhs.source == .personalSchedule }

        // 全天事项不能抢占任何定时日程，即使自身正在进行也一样。
        if lhs.isAllDay != rhs.isAllDay { return !lhs.isAllDay }

        let lhsIsActive = isActive(lhs, at: date, calendar: calendar)
        let rhsIsActive = isActive(rhs, at: date, calendar: calendar)
        if lhsIsActive != rhsIsActive { return lhsIsActive }
        if lhs.startDate != rhs.startDate { return lhs.startDate < rhs.startDate }
        return lhs.id < rhs.id
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
