//
//  NextCourseProvider.swift
//  ScheduleWidgetExtension
//
//  桌面与锁屏“下节课”组件共用的数据快照和时间线。
//

import Foundation
import WidgetKit

/// 一张“下节课”组件快照在某时刻应显示的数据。
/// 它不包含任何 SwiftUI 布局，因此桌面与锁屏可以各自拥有独立的内容 View。
struct NextCourseEntry: TimelineEntry
{
    let date: Date
    let nextCourse: WidgetNextCourse?
    /// 中号桌面组件显示的未来课程；锁屏和小号不会读取这个字段。
    let upcomingCourses: [WidgetNextCourse]
    let isCampusPassActive: Bool
}

/// 桌面和锁屏共用的时间线提供者。
/// 两个组件读取同一份课程、订阅状态和刷新时机，避免出现一个先切换、另一个滞后的情况。
struct NextCourseProvider: TimelineProvider
{
    func placeholder(in _: Context) -> NextCourseEntry
    {
        NextCourseEntry(
            date: .now,
            nextCourse: nil,
            upcomingCourses: [],
            isCampusPassActive: false
        )
    }

    private func currentEntry(at date: Date = .now) -> NextCourseEntry
    {
        let nextCourse = NextCourseWidgetShared.currentOrNextCourse(at: date)
        return NextCourseEntry(
            date: date,
            nextCourse: nextCourse,
            // 中号固定展示“今天”的日期卡，右侧单独读取未来将要上的课程。
            upcomingCourses: NextCourseWidgetShared.upcomingCourses(at: date),
            isCampusPassActive: IAPWidgetShared.loadStatus(at: date).isActive
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (NextCourseEntry) -> Void
    )
    {
        let entry = currentEntry()

        // Canvas 没有 App Group 课程时仍能检查排版；真实组件不会写入这份演示数据。
        if context.isPreview, entry.nextCourse == nil
        {
            completion(previewEntry(at: entry.date))
        }
        else
        {
            completion(entry)
        }
    }

    func getTimeline(
        in _: Context,
        completion: @escaping (Timeline<NextCourseEntry>) -> Void
    )
    {
        let entry = currentEntry()
        let transitionDate = NextCourseWidgetShared.nextRefreshDate(after: entry.date)
        let subscriptionExpiration = IAPWidgetShared.nextExpirationDate(after: entry.date)
        let countdownRefresh = NextCourseWidgetShared.nextCountdownRefreshDate(after: entry.date)

        // 订阅先到期时，在到期点重新读取状态，届时两个组件都会切到锁定页。
        if let subscriptionExpiration,
           subscriptionExpiration <= transitionDate,
           (countdownRefresh == nil || subscriptionExpiration <= countdownRefresh!)
        {
            completion(Timeline(entries: [entry], policy: .after(subscriptionExpiration)))
            return
        }

        // 课程开始时从“下一节课”变成“正在上课”，下课后再选出下一门课。
        let transitionEntry = currentEntry(at: transitionDate)
        let refreshDate = [
            NextCourseWidgetShared.nextRefreshDate(after: transitionEntry.date),
            subscriptionExpiration,
            countdownRefresh,
        ]
        .compactMap { $0 }
        .min() ?? NextCourseWidgetShared.nextRefreshDate(after: transitionEntry.date)

        completion(Timeline(entries: [entry, transitionEntry], policy: .after(refreshDate)))
    }

    private func previewEntry(at date: Date) -> NextCourseEntry
    {
        let startDate = date.addingTimeInterval(60 * 60)
        let endDate = startDate.addingTimeInterval(45 * 60)
        return NextCourseEntry(
            date: date,
            nextCourse: WidgetNextCourse(
                id: "demo-next-course",
                name: "编译原理",
                startDate: startDate,
                endDate: endDate,
                room: "逸夫楼 C302",
                teacher: "张老师",
                periodText: "第 3-4 节"
            ),
            upcomingCourses: [
                WidgetNextCourse(
                    id: "demo-next-course",
                    name: "编译原理",
                    startDate: startDate,
                    endDate: endDate,
                    room: "逸夫楼 C302",
                    teacher: "张老师",
                    periodText: "第 3-4 节"
                ),
                WidgetNextCourse(
                    id: "demo-second-course",
                    name: "软件工程",
                    startDate: endDate.addingTimeInterval(60 * 60),
                    endDate: endDate.addingTimeInterval(2.5 * 60 * 60),
                    room: "三教 A303",
                    teacher: "李老师",
                    periodText: "第 5-6 节"
                ),
                WidgetNextCourse(
                    id: "demo-third-course",
                    name: "数据结构",
                    startDate: endDate.addingTimeInterval(4 * 60 * 60),
                    endDate: endDate.addingTimeInterval(5.5 * 60 * 60),
                    room: "主楼 B201",
                    teacher: "王老师",
                    periodText: "第 7-8 节"
                ),
            ],
            isCampusPassActive: true
        )
    }
}
