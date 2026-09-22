//
//  PersonalScheduleWidget.swift
//  ScheduleWidgetExtension
//
//  中号“近期日程”桌面组件。
//

import Foundation
import SwiftUI
import WidgetKit
import UIKit

/// WidgetKit 在某个时刻要渲染的日程快照。
/// Provider 已经完成排序和数量统计，SwiftUI View 只负责排版，避免两处各自筛选。
struct PersonalScheduleEntry: TimelineEntry
{
    let date: Date
    let events: [WidgetScheduleItem]
    let remainingEventCount: Int
    let isCampusPassActive: Bool
}

/// 只用于 Canvas 与组件库；真实组件绝不会将它写回 App Group。
private enum ScheduleWidgetPreviewData
{
    static func entry(at date: Date = .now) -> PersonalScheduleEntry
    {
        let events = [
            WidgetScheduleItem(
                id: "demo-meeting",
                title: "项目组会议",
                startDate: date.addingTimeInterval(60 * 60),
                endDate: date.addingTimeInterval(90 * 60),
                location: "逸夫楼 C302",
                detail: nil,
                source: .personalSchedule,
                isAllDay: false
            ),
            WidgetScheduleItem(
                id: "demo-review",
                title: "复习编译原理",
                startDate: date.addingTimeInterval(26 * 60 * 60),
                endDate: nil,
                location: nil,
                detail: nil,
                source: .personalSchedule,
                isAllDay: false
            ),
            WidgetScheduleItem(
                id: "demo-assignment",
                title: "提交课程作业",
                startDate: date.addingTimeInterval(50 * 60 * 60),
                endDate: nil,
                location: nil,
                detail: nil,
                source: .personalSchedule,
                isAllDay: false
            ),
        ]

        return PersonalScheduleEntry(
            date: date,
            events: events,
            remainingEventCount: 2,
            isCampusPassActive: true
        )
    }
}

/// 只负责时间线，日程筛选规则统一放在 SharedWidget，供 App 与 Extension 复用。
struct PersonalScheduleProvider: TimelineProvider
{
    func placeholder(in _: Context) -> PersonalScheduleEntry
    {
        PersonalScheduleEntry(
            date: .now,
            events: [],
            remainingEventCount: 0,
            isCampusPassActive: false
        )
    }

    private func currentEntry(at date: Date = .now) -> PersonalScheduleEntry
    {
        let presentation = PersonalScheduleWidgetShared.recentPresentation(at: date)
        return PersonalScheduleEntry(
            date: date,
            events: presentation?.items ?? [],
            remainingEventCount: presentation?.remainingItemCount ?? 0,
            isCampusPassActive: IAPWidgetShared.loadStatus(at: date).isActive
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (PersonalScheduleEntry) -> Void
    )
    {
        let entry = currentEntry()
        completion(context.isPreview && entry.events.isEmpty
            ? ScheduleWidgetPreviewData.entry(at: entry.date)
            : entry)
    }

    func getTimeline(
        in _: Context,
        completion: @escaping (Timeline<PersonalScheduleEntry>) -> Void
    )
    {
        let entry = currentEntry()
        // 任一日程的开始／结束以及订阅到期，都可能改变组件内容。
        let scheduleRefreshDate = PersonalScheduleWidgetShared.nextRefreshDate(after: entry.date)
        let refreshDate = [
            scheduleRefreshDate,
            IAPWidgetShared.nextExpirationDate(after: entry.date),
        ]
        .compactMap { $0 }
        .min() ?? scheduleRefreshDate

        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }
}

struct PersonalScheduleWidgetEntryView: View
{
    let entry: PersonalScheduleEntry

    var body: some View
    {
        Group
        {
            if entry.isCampusPassActive
            {
                VStack(alignment: .leading, spacing: 7)
                {
                    HStack
                    {
                        Label("近期日程", systemImage: "calendar.badge.clock")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)

                        Spacer()

                        Text("未来 7 天")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    if entry.events.isEmpty
                    {
                        PersonalScheduleWidgetEmptyView()
                    }
                    else
                    {
                        ForEach(entry.events)
                        { event in
                            PersonalScheduleWidgetEventRow(event: event)
                        }

                        if entry.remainingEventCount > 0
                        {
                            Text("未来一星期内还有 \(entry.remainingEventCount) 条")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                }
            }
            else
            {
                PersonalScheduleWidgetLockedView()
            }
        }
        .padding(13)
        .containerBackground(for: .widget)
        {
            Color(uiColor: .secondarySystemGroupedBackground)
        }
    }

}

/// 单条事项最多两行，并在第二行标明日期，支持跨天展示未来七天内的三条日程。
private struct PersonalScheduleWidgetEventRow: View
{
    let event: WidgetScheduleItem

    private var accentColor: Color
    {
        event.source == .schoolCalendar ? .green : .orange
    }

    private var dateAndTimeText: String
    {
        let calendar = Calendar.current
        let dateText: String

        if calendar.isDateInToday(event.startDate)
        {
            dateText = "今天"
        }
        else if calendar.isDateInTomorrow(event.startDate)
        {
            dateText = "明天"
        }
        else
        {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "M月d日 E"
            dateText = formatter.string(from: event.startDate)
        }

        let timeText = event.isAllDay
            ? "全天"
            : event.startDate.formatted(date: .omitted, time: .shortened)
        return "\(dateText) · \(timeText)"
    }

    var body: some View
    {
        HStack(spacing: 8)
        {
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 3, height: 30)

            VStack(alignment: .leading, spacing: 2)
            {
                Text(event.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                HStack(spacing: 5)
                {
                    Image(systemName: event.isAllDay ? "sun.max" : "clock")
                    Text(dateAndTimeText)

                    if let location = event.location, !location.isEmpty
                    {
                        Text("· \(location)")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct PersonalScheduleWidgetEmptyView: View
{
    var body: some View
    {
        VStack(alignment: .leading, spacing: 8)
        {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(.green)

            Text("未来 7 天暂无安排")
                .font(.system(size: 18, weight: .semibold))

            Text("新增日程或同步校历后会显示在这里")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
}

/// 日程内容属于校园通行证权益；未订阅时不读取任何日程展示字段。
private struct PersonalScheduleWidgetLockedView: View
{
    var body: some View
    {
        VStack(spacing: 10)
        {
            Image(systemName: "lock.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.blue)

            Text("校园通行证未生效")
                .font(.system(size: 16, weight: .bold))
                .multilineTextAlignment(.center)

            Text("开通校园通行证后显示近期日程")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PersonalScheduleWidget: Widget
{
    static let kind = WidgetAppGroup.Kind.personalSchedule

    var body: some WidgetConfiguration
    {
        StaticConfiguration(kind: Self.kind, provider: PersonalScheduleProvider())
        { entry in
            PersonalScheduleWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("近期日程")
        .description("显示未来七天内优先级最高的三条日程")
        .supportedFamilies([.systemMedium])
    }
}

#Preview("近期日程", as: .systemMedium, widget: {
    PersonalScheduleWidget()
}, timelineProvider: {
    PersonalScheduleProvider()
})
