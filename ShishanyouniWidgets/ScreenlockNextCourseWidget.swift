//
//  ScreenlockNextCourseWidget.swift
//  ScheduleWidgetExtension
//
//  锁屏矩形“下节课”组件。
//

import SwiftUI
import WidgetKit

/// 只负责锁屏矩形组件，不包含桌面小组件的布局或状态分支。
struct ScreenlockNextCourseWidget: Widget
{
    static let kind = WidgetAppGroup.Kind.screenlockNextCourse

    var body: some WidgetConfiguration
    {
        StaticConfiguration(kind: Self.kind, provider: NextCourseProvider())
        { entry in
            ScreenlockNextCourseWidgetView(entry: entry)
        }
        .configurationDisplayName("锁屏下节课")
        .description("在锁定屏幕显示当前课程或下一门课程")
        .supportedFamilies([.accessoryRectangular])
    }
}

/// 锁屏组件的入口；只在锁屏状态之间切换，不认识桌面 View。
private struct ScreenlockNextCourseWidgetView: View
{
    let entry: NextCourseEntry

    var body: some View
    {
        Group
        {
            if !entry.isCampusPassActive
            {
                ScreenlockNextCourseLockedView()
            }
            else if let course = entry.nextCourse
            {
                ScreenlockNextCourseCourseView(course: course)
            }
            else
            {
                ScreenlockNextCourseEmptyView()
            }
        }
        .padding(8)
        .containerBackground(for: .widget)
        {
            Color.clear
        }
    }
}

/// 锁屏组件的“有课程”状态。
/// 根 VStack 固定为：课程名称 → 教室/老师 → 开始时间 - 结束时间。
private struct ScreenlockNextCourseCourseView: View
{
    let course: WidgetNextCourse

    var body: some View
    {
        VStack(alignment: .leading, spacing: 2)
        {
            Text(course.name)
                .font(.system(size: 13, weight: .bold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .widgetAccentable()
            
            HStack(alignment: .center, spacing: 6)
            {
                if let room = course.room, !room.isEmpty
                {
                    HStack(alignment: .center, spacing: 3)
                    {
                        Image(systemName: "mappin.and.ellipse")
                            .frame(width: 13, height: 13)

                        Text(room)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(height: 15, alignment: .center)
                }

                if let teacher = course.teacher, !teacher.isEmpty
                {
                    HStack(alignment: .center, spacing: 3)
                    {
                        Image(systemName: "person.fill")
                            .frame(width: 13, height: 13)

                        Text(teacher)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(height: 15, alignment: .center)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            HStack(spacing: 4)
            {
                Text(course.startDate, style: .time)
                    .font(.caption2.monospacedDigit())

                Text("-")
                    .font(.caption2)

                Text(course.endDate, style: .time)
                    .font(.caption2.monospacedDigit())
            }
            .lineLimit(1)
        }
    }
}

/// 锁屏组件的“未来 2 天无课”状态；根节点就是独立的 VStack。
private struct ScreenlockNextCourseEmptyView: View
{
    var body: some View
    {
        VStack(alignment: .leading, spacing: 4)
        {
            Image(systemName: "calendar.badge.checkmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)

            Text("2天内暂无课程")
                .font(.caption.weight(.bold))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
    }
}

/// 锁屏组件的未开通状态；根节点就是独立的 VStack。
private struct ScreenlockNextCourseLockedView: View
{
    var body: some View
    {
        VStack(alignment: .center, spacing: 4)
        {
            Image(systemName: "lock.fill")
                .font(.caption .weight(.semibold))
                .foregroundStyle(.blue)

            Text("请开通校园通行证使用")
                .font(.caption .weight(.bold))
                
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
    }
}

#Preview("锁屏下节课", as: .accessoryRectangular, widget: {
    ScreenlockNextCourseWidget()
}, timelineProvider: {
    NextCourseProvider()
})
