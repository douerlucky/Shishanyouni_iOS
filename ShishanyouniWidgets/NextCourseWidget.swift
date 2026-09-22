//
//  NextCourseWidget.swift
//  ScheduleWidgetExtension
//
//  桌面“下节课”组件：小号显示一节，中号显示当日课程概览。
//  锁屏布局独立放在 ScreenlockNextCourseWidget.swift。
//

import SwiftUI
import UIKit
import WidgetKit

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
        .description("小号显示一节课，中号显示未来三节课程")
        // 保持原 kind 不变；已放在用户桌面上的小号组件不会失效，只多出中号尺寸。
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// 桌面入口只在尺寸之间分发，具体的小号、中号 View 完全分离。
private struct NextCourseWidgetView: View
{
    @Environment(\.widgetFamily) private var family
    let entry: NextCourseEntry

    var body: some View
    {
        Group
        {
            if !entry.isCampusPassActive
            {
                NextCourseDesktopLockedView()
            }
            else if family == .systemMedium
            {
                if entry.upcomingCourses.isEmpty
                {
                    NextCourseDesktopEmptyView()
                }
                else
                {
                    NextCourseDesktopMediumView(
                        courses: entry.upcomingCourses,
                        referenceDate: entry.date
                    )
                }
            }
            else if let course = entry.nextCourse
            {
                NextCourseDesktopSmallView(course: course, referenceDate: entry.date)
            }
            else
            {
                NextCourseDesktopEmptyView()
            }
        }
        .padding(family == .systemMedium ? 12 : 14)
        .containerBackground(for: .widget)
        {
            entry.isCampusPassActive
                ? Color(uiColor: .secondarySystemGroupedBackground)
                : Color.clear
        }
    }
}

/// 小号只服务“现在最重要的一节课”，不引入中号的列表结构。
private struct NextCourseDesktopSmallView: View
{
    let course: WidgetNextCourse
    let referenceDate: Date

    private var isInProgress: Bool
    {
        course.startDate <= referenceDate && referenceDate < course.endDate
    }

    private var accentColor: Color { isInProgress ? .green : .blue }

    var body: some View
    {
        VStack(alignment: .leading, spacing: 5)
        {
            HStack(alignment: .center, spacing: 6)
            {
                Text(isInProgress ? "正在上课" : "下一节课")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accentColor)

                Spacer(minLength: 0)

                Text(countdownText)
                    .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(accentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(height: 15)

            Text(course.name)
                .font(.system(size: 16, weight: .bold))
                // 课程名允许占两行；不能再被强行压成一行省略号。
                .lineLimit(2)
                .minimumScaleFactor(0.65)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

            Text(courseTimeText)
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            VStack(alignment: .leading, spacing: 1)
            {
                if let teacher = course.teacher, !teacher.isEmpty
                {
                    NextCourseMetadataLine(text: teacher, systemImage: "person.fill")
                }

                if let room = course.room, !room.isEmpty
                {
                    NextCourseMetadataLine(text: room, systemImage: "mappin.and.ellipse")
                }
            }

            Text(course.periodText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(accentColor)
                .lineLimit(1)
        }
    }

    /// 大于 24 小时只报“X 天后”；进入 24 小时窗口才显示小时和分钟，避免秒数挤出省略号。
    private var countdownText: String
    {
        let targetDate = isInProgress ? course.endDate : course.startDate
        let seconds = max(targetDate.timeIntervalSince(referenceDate), 0)

        if seconds > 24 * 60 * 60
        {
            return "\(Int(ceil(seconds / (24 * 60 * 60))))天后"
        }

        let components = Calendar.current.dateComponents([.hour, .minute], from: referenceDate, to: targetDate)
        let hours = max(components.hour ?? 0, 0)
        let minutes = max(components.minute ?? 0, 0)
        if hours > 0 { return "\(hours)小时\(minutes)分后" }
        if minutes > 0 { return "\(minutes)分后" }
        return isInProgress ? "即将下课" : "即将上课"
    }

    private var courseTimeText: String
    {
        "\(dayPrefix(for: course.startDate)) \(timeText(course.startDate))–\(timeText(course.endDate))"
    }
}

/// 中号左侧始终是“今天”的日期卡，右侧显示未来将要上的三节课程。
private struct NextCourseDesktopMediumView: View
{
    let courses: [WidgetNextCourse]
    let referenceDate: Date

    private var visibleCourses: [WidgetNextCourse] { Array(courses.prefix(3)) }

    var body: some View
    {
        HStack(alignment: .center, spacing: 12)
        {
            NextCourseDateCard(date: referenceDate)

            VStack(alignment: .leading, spacing: 8)
            {
                ForEach(visibleCourses)
                { course in
                    NextCourseMediumRow(course: course)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct NextCourseDateCard: View
{
    let date: Date

    var body: some View
    {
        VStack(spacing: 2)
        {
            Text(date.formatted(.dateTime.month()))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Text(date.formatted(.dateTime.day()))
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text(weekdayText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        // referenceDate 来自 Widget 时间线，因此它始终代表用户看到组件时的“今天”。
        .frame(width: 98, height: 98)
        .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }

    private var weekdayText: String
    {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}

private struct NextCourseMediumRow: View
{
    let course: WidgetNextCourse

    var body: some View
    {
        HStack(alignment: .center, spacing: 7)
        {
            // 用窄竖条标记一节独立课程，三行之间不用再叠横向分隔线。
            RoundedRectangle(cornerRadius: 2)
                .fill(.blue)
                .frame(width: 3, height: 29)

            VStack(alignment: .leading, spacing: 2)
            {
                Text(course.name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                HStack(spacing: 4)
                {
                    Text("\(dayPrefix(for: course.startDate)) \(timeText(course.startDate))–\(timeText(course.endDate))")
                        .foregroundStyle(.blue)

                    if let room = course.room, !room.isEmpty
                    {
                        Text("· \(room)")
                    }
                }
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 29)
    }
}

/// 元数据宁愿自动隐藏，也不在课程组件里出现“……”半截信息。
private struct NextCourseMetadataLine: View
{
    let text: String
    let systemImage: String

    var body: some View
    {
        ViewThatFits(in: .horizontal)
        {
            Label(text, systemImage: systemImage)
                .font(.system(size: 11))
                .fixedSize(horizontal: true, vertical: false)

            Label(text, systemImage: systemImage)
                .font(.system(size: 9))
                .fixedSize(horizontal: true, vertical: false)

            EmptyView()
        }
        .foregroundStyle(.secondary)
    }
}

/// 未来 2 天无课时，小号与中号复用同一个空状态。
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

/// 桌面未开通状态；锁屏拥有自己的独立锁定 View。
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

private func dayPrefix(for date: Date) -> String
{
    let calendar = Calendar.current
    if calendar.isDateInToday(date) { return "今天" }
    if calendar.isDateInTomorrow(date) { return "明天" }
    if let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: .now),
       calendar.isDate(date, inSameDayAs: dayAfterTomorrow)
    {
        return "后天"
    }
    return date.formatted(.dateTime.month().day())
}

private func timeText(_ date: Date) -> String
{
    date.formatted(date: .omitted, time: .shortened)
}

#Preview("下节课（小号）", as: .systemSmall, widget: {
    NextCourseWidget()
}, timelineProvider: {
    NextCourseProvider()
})

#Preview("下节课（中号）", as: .systemMedium, widget: {
    NextCourseWidget()
}, timelineProvider: {
    NextCourseProvider()
})
