//
//  NextCourseWidget.swift
//  ScheduleWidgetExtension
//
//  桌面小型“下节课”组件。
//

import SwiftUI
import UIKit
import WidgetKit

/// 只负责桌面小组件，不包含锁屏组件的布局或状态分支。
struct NextCourseWidget: Widget
{
    static let kind = WidgetAppGroup.Kind.nextCourse

    var body: some WidgetConfiguration
    {
        StaticConfiguration(kind: Self.kind, provider: NextCourseProvider())
        { entry in
            NextCourseWidgetView(entry: entry)
        }
        .configurationDisplayName("下节课")
        .description("显示当前课程或未来 2 天内的下一门课程")
        .supportedFamilies([.systemSmall])
    }
}

/// 桌面小组件的入口；只在桌面状态之间切换，不认识锁屏 View。
private struct NextCourseWidgetView: View
{
    let entry: NextCourseEntry

    var body: some View
    {
        Group
        {
            if !entry.isCampusPassActive
            {
                NextCourseDesktopLockedView()
            }
            else if let course = entry.nextCourse
            {
                NextCourseDesktopCourseView(course: course, referenceDate: entry.date)
            }
            else
            {
                NextCourseDesktopEmptyView()
            }
        }
        .padding(14)
        .containerBackground(for: .widget)
        {
            entry.isCampusPassActive
                ? Color(uiColor: .secondarySystemGroupedBackground)
                : Color.clear
        }
    }
}

/// 桌面小组件的“有课程”状态。
private struct NextCourseDesktopCourseView: View
{
    let course: WidgetNextCourse
    let referenceDate: Date

    private var isInProgress: Bool
    {
        course.startDate <= referenceDate && referenceDate < course.endDate
    }

    var body: some View
    {
        VStack(alignment: .leading, spacing: 8)
        {
            HStack(alignment: .center, spacing: 10)
            {
                Text(isInProgress ? "正在上课" : "下一节课")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(isInProgress ? .green : .blue)

                Text(isInProgress ? course.endDate : course.startDate, style: .timer)
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(isInProgress ? .green : .blue)
            }
            .frame(height: 18, alignment: .center)

            Text(course.name)
                .font(.system(size: 17, weight: .bold))
                .lineLimit(2)
                // 课程名优先使用两行显示，不能被下方的教师、地点信息挤成省略号。
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

            VStack(alignment: .leading, spacing: 2)
            {
                if let teacher = course.teacher, !teacher.isEmpty
                {
                    Label(teacher, systemImage: "person.fill")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let room = course.room, !room.isEmpty
                {
                    Label(room, systemImage: "mappin.and.ellipse")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)

            Text(course.periodText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.blue)
                .lineLimit(1)
        }
    }
}

/// 桌面小组件的“未来 2 天无课”状态。
private struct NextCourseDesktopEmptyView: View
{
    var body: some View
    {
        VStack(alignment: .leading, spacing: 8)
        {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.green)

            Text("2天内暂无课程")
                .font(.system(size: 16, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 0)
        }
    }
}

/// 桌面小组件的未开通状态；根节点就是独立的 VStack。
private struct NextCourseDesktopLockedView: View
{
    var body: some View
    {
        VStack(alignment: .center, spacing: 8)
        {
            Image(systemName: "lock.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.blue)

            Text("校园通行证未生效")
                .font(.system(size: 15, weight: .bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            Text("请开通校园通行证使用")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)
        }
    }
}

#Preview("下节课", as: .systemSmall, widget: {
    NextCourseWidget()
}, timelineProvider: {
    NextCourseProvider()
})
