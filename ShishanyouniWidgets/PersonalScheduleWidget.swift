//
//  PersonalScheduleWidget.swift
//  ScheduleWidgetExtension
//
//  Created by douer_lucky on 2026/9/11.
//

import Foundation
import SwiftUI
import WidgetKit
import UIKit

//定义 Widget 的时间线数据。
struct PersonalScheduleEntry: TimelineEntry
{
    let date: Date // 这张 Widget 快照从何时开始生效
    let nextEvent: WidgetScheduleItem? // 要显示的下一条事件
    /// 在生成这张快照时，校园通行证是否有效。
    let isCampusPassActive: Bool
}

// 只供 Canvas 与开发版使用的演示数据。
// 正式版不会把这条假日程展示给用户。
private enum ScheduleWidgetPreviewData
{
    static func entry(at date: Date = .now) -> PersonalScheduleEntry
    {
        let event = WidgetScheduleItem(
            id: "demo",
            title: "项目组会议",
            startDate: date.addingTimeInterval(60 * 60),
            endDate: nil,
            location: "逸夫楼 C302",
            detail: "预览日程",
            source: .personalSchedule,
            isAllDay: false
        )

        return PersonalScheduleEntry(
            date: date,
            nextEvent: event,
            // Canvas 和组件库的演示数据不应被真实订阅状态遮住。
            isCampusPassActive: true
        )
    }
}

struct PersonalScheduleProvider: TimelineProvider
{
    // Widget 还没有拿到真实数据时，系统在组件库中展示的锁定状态。
    // 组件库不能可靠代表当前账户权益，因此不展示假日程，避免造成“未购买也能用”的误解。
    func placeholder(in _: Context) -> PersonalScheduleEntry
    {
        PersonalScheduleEntry(
            date: .now,
            nextEvent: nil,
            isCampusPassActive: false
        )
    }

    // 正式 Widget 永远从 App Group 读取，Debug 与 Release 走同一条真实数据链路。
    private func currentEntry(at date: Date = .now) -> PersonalScheduleEntry
    {
        let subscriptionStatus = IAPWidgetShared.loadStatus(at: date)
        return PersonalScheduleEntry(
            date: date,
            nextEvent: PersonalScheduleWidgetShared.nextItem(at: date),
            isCampusPassActive: subscriptionStatus.isActive
        )
    }

    // Canvas 和系统快照使用的快速数据请求。
    func getSnapshot(
        in context: Context,
        completion: @escaping (PersonalScheduleEntry) -> Void
    )
    {
        let entry = currentEntry()
        // Xcode Canvas / Widget Gallery 在没有 App Group 数据时仍展示设计稿，
        // 真正放到桌面上的 Widget 则显示空状态而不是虚构日程。
        if context.isPreview, entry.nextEvent == nil
        {
            completion(ScheduleWidgetPreviewData.entry(at: entry.date))
        }
        else
        {
            completion(entry)
        }
    }

    // Widget 正式运行时向系统交付的数据快照。
    // 到下一条事项的开始/结束或订阅到期时，让系统重新向 App Group 读取数据。
    func getTimeline(
        in _: Context,
        completion: @escaping (Timeline<PersonalScheduleEntry>) -> Void
    )
    {
        let entry = currentEntry()
        // 日程没有变化时也要在订阅到期点重新生成，避免过期后仍显示权益内容。
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

    private var accentColor: Color
    {
        entry.nextEvent?.source == .schoolCalendar ? .green : .orange
    }

    var body: some View
    {
        Group
        {
            if entry.isCampusPassActive
            {
                VStack(alignment: .leading, spacing: 12)
                {
                    HStack
                    {
                        Label("下一条安排", systemImage: "calendar.badge.clock")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)

                        Spacer()

                        if let event = entry.nextEvent
                        {
                            Text(event.source.displayName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(accentColor.opacity(0.12), in: Capsule())
                        }
                    }

                    if let event = entry.nextEvent
                    {
                        HStack(alignment: .top, spacing: 12)
                        {
                            Image(systemName: event.source == .schoolCalendar ? "calendar" : "checklist")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(accentColor)
                                .frame(width: 44, height: 44)
                                .background(accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))

                            VStack(alignment: .leading, spacing: 6)
                            {
                                Text(event.title)
                                    .font(.system(size: 18, weight: .semibold))
                                    .lineLimit(2)

                                if event.isAllDay
                                {
                                    Label("全天", systemImage: "sun.max")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                else
                                {
                                    HStack(spacing: 8)
                                    {
                                        Label
                                        {
                                            Text(event.startDate, style: .time)
                                        }
                                        icon:
                                        {
                                            Image(systemName: "clock")
                                        }
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)

                                        Text(event.startDate, style: .relative)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(accentColor)
                                    }
                                }

                                if let location = event.location,
                                   !location.isEmpty
                                {
                                    Label(location, systemImage: "mappin.and.ellipse")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }

                                if let detail = event.detail,
                                   !detail.isEmpty
                                {
                                    Text(detail)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer(minLength: 0)
                        }
                    }

                    else
                    {
                        VStack(alignment: .leading, spacing: 8)
                        {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.green)

                            Text("接下来暂无安排")
                                .font(.system(size: 18, weight: .semibold))

                            Text("新增日程或同步校历后会显示在这里")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
            else
            {
                PersonalScheduleWidgetLockedView()
            }
        }
        .padding(16)
        .containerBackground(for: .widget)
        {
            Color(uiColor: .secondarySystemGroupedBackground)
        }
    }
}

/// 日程内容属于校园通行证权益；未订阅时不渲染展示字段，只显示引导页。
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

            Text("开通校园通行证后显示下一条日程安排")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PersonalScheduleWidget: Widget
{
    // 主 App 用这个稳定标识符主动刷新本 Widget。
    static let kind = WidgetAppGroup.Kind.personalSchedule

    var body: some WidgetConfiguration
    {
        StaticConfiguration(
            kind: Self.kind,
            provider: PersonalScheduleProvider() //把 Provider 交给 WidgetKit
        )
        { entry in
            PersonalScheduleWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("日程")
        .description("显示下一条日程安排")
        .supportedFamilies([.systemMedium])
    }
}

#Preview("日程组件", as: .systemMedium, widget: {
    PersonalScheduleWidget()
}, timelineProvider: {
    // Canvas 直接复用正式 Provider，之后改数据来源时预览也会同步更新。
    PersonalScheduleProvider()
})
