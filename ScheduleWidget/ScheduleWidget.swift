//
//  ScheduleWidget.swift
//  ScheduleWidget
//
//  Created by douer_lucky on 2026/4/23.
//

import WidgetKit
import SwiftUI
import UIKit

private enum WidgetShared
{
    static let appGroupID = "group.cn.edu.hzau.shishanyouni"
    static let savedCoursesKey = "saved_courses"
    static let currentWeekKey = "schedule_current_week"
    static let backgroundImageFilenameKey = "scheduleBackgroundImageFilename"
    static let backgroundOpacityKey = "scheduleBackgroundOpacity"
    
    static let campusPassActiveKey = "iap_campus_pass_active" // 当前校园通行证是否有效
    static let campusPassProductIDKey = "iap_campus_pass_product_id" // 当前生效的是哪个订阅商品
    static let campusPassExpirationKey = "iap_campus_pass_expiration" // 订阅到期时间
}

struct WidgetCourse: Codable, Identifiable
{
    let id: String
    let name: String
    let day: Int
    let start: Int
    let step: Int
    let room: String?
    let teacher: String?
    let weekList: [Int]
    let weeks: String?
    let term: String?
    let colorRandom: Int
    let customColorHex: String?
    let isManual: Bool

    var endPeriod: Int { start + step - 1 }
}

struct SimpleEntry: TimelineEntry
{
    let date: Date
    let currentWeek: Int
    let currentMonth: Int
    let weekDates: [Int] // 周一到周日日期
    let todayIndex: Int // 周一=1 ... 周日=7
    let currentPeriod: Int?
    let weeklyCourses: [WidgetCourse]
    let backgroundFilename: String
    let backgroundOpacity: Double
}

struct Provider: TimelineProvider
{
    func placeholder(in context: Context) -> SimpleEntry
    {
        SimpleEntry(
            date: Date(),
            currentWeek: 1,
            currentMonth: 1,
            weekDates: [1, 2, 3, 4, 5, 6, 7],
            todayIndex: 1,
            currentPeriod: nil,
            weeklyCourses: [],
            backgroundFilename: "",
            backgroundOpacity: 0.2
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ())
    {
        completion(buildEntry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ())
    {
        let now = Date()
        var entries: [SimpleEntry] = []
        for offset in 0 ..< 6
        {
            if let date = Calendar.current.date(byAdding: .minute, value: offset * 30, to: now)
            {
                entries.append(buildEntry(at: date))
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func buildEntry(at date: Date) -> SimpleEntry
    {
        let courses = loadSharedCourses()
        let week = loadCurrentWeek()
        let (month, dates) = computeWeekDates(from: date)
        let today = weekdayIndex(from: date)
        let period = currentPeriodNumber(for: date)
        let (bgName, bgOpacity) = loadBackgroundMeta()

        let weeklyCourses = courses
            .filter { $0.weekList.contains(week) }
            .sorted
            {
                if $0.day != $1.day { return $0.day < $1.day }
                return $0.start < $1.start
            }

        return SimpleEntry(
            date: date,
            currentWeek: week,
            currentMonth: month,
            weekDates: dates,
            todayIndex: today,
            currentPeriod: period,
            weeklyCourses: weeklyCourses,
            backgroundFilename: bgName,
            backgroundOpacity: bgOpacity
        )
    }

    private func loadSharedCourses() -> [WidgetCourse]
    {
        guard let shared = UserDefaults(suiteName: WidgetShared.appGroupID),
              let data = shared.data(forKey: WidgetShared.savedCoursesKey)
        else
        {
            return []
        }
        return (try? JSONDecoder().decode([WidgetCourse].self, from: data)) ?? []
    }

    private func loadCurrentWeek() -> Int
    {
        guard let shared = UserDefaults(suiteName: WidgetShared.appGroupID) else { return 1 }
        let value = shared.integer(forKey: WidgetShared.currentWeekKey)
        return max(value, 1)
    }

    private func loadBackgroundMeta() -> (String, Double)
    {
        guard let shared = UserDefaults(suiteName: WidgetShared.appGroupID) else { return ("", 0.2) }
        let name = shared.string(forKey: WidgetShared.backgroundImageFilenameKey) ?? ""
        let opacity = shared.object(forKey: WidgetShared.backgroundOpacityKey) as? Double ?? 0.2
        return (name, opacity)
    }

    private func computeWeekDates(from date: Date) -> (Int, [Int])
    {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        guard let monday = cal.date(from: comps) else { return (cal.component(.month, from: date), [0, 0, 0, 0, 0, 0, 0]) }

        var days: [Int] = []
        for i in 0 ..< 7
        {
            if let d = cal.date(byAdding: .day, value: i, to: monday)
            {
                days.append(cal.component(.day, from: d))
            }
        }
        let month = cal.component(.month, from: monday)
        return (month, days)
    }

    private func weekdayIndex(from date: Date) -> Int
    {
        let w = Calendar.current.component(.weekday, from: date)
        return w == 1 ? 7 : (w - 1)
    }

    // 与 ScheduleView.TimeScheduleView 相同节次时间逻辑
    private func currentPeriodNumber(for date: Date) -> Int?
    {
        let classPeriods: [(period: Int, displayStart: String, end: String)] = [
            (1, "7:30", "8:45"),
            (2, "8:45", "9:40"),
            (3, "9:40", "10:45"),
            (4, "10:45", "11:40"),
            (5, "14:00", "15:15"),
            (6, "15:15", "16:10"),
            (7, "16:10", "17:15"),
            (8, "17:15", "18:10"),
            (9, "18:30", "19:45"),
            (10, "19:45", "20:35"),
            (11, "20:35", "21:25"),
            (12, "21:25", "22:15"),
        ]

        let c = Calendar.current
        let hour = c.component(.hour, from: date)
        let minute = c.component(.minute, from: date)
        let current = hour * 60 + minute

        for p in classPeriods
        {
            guard let start = minutes(from: p.displayStart),
                  let end = minutes(from: p.end)
            else
            {
                continue
            }
            if current >= start && current < end { return p.period }
        }
        return nil
    }

    private func minutes(from time: String) -> Int?
    {
        let parts = time.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]),
              let m = Int(parts[1]) else { return nil }
        return h * 60 + m
    }
}

struct ScheduleWidgetEntryView: View
{
    var entry: Provider.Entry
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    private let weekdays = ["一", "二", "三", "四", "五", "六", "日"]
    private let periodCount = 12
    private let rowSpacing: CGFloat = 1.5
    private let columnSpacing: CGFloat = 2
    private let periodColumnWidth: CGFloat = 20
    
    private var isAccentedMode: Bool
    {
        if #available(iOS 17.0, *)
        {
            return widgetRenderingMode == .accented
        }
        return false
    }

    var body: some View
    {
        GeometryReader
        { geo in
            ZStack(alignment: .topLeading)
            {
                backgroundImageView(in: geo.size)
                // 在系统 accented/Liquid Glass 渲染下，增加轻微覆盖以保证可读性
                if isAccentedMode
                {
                    Color.black.opacity(0.12)
                }

                let horizontalPadding: CGFloat = 8
                let verticalPadding: CGFloat = 6
                let topBarHeight: CGFloat = 18
                let headerHeight: CGFloat = 30
                let availableHeight = max(
                    geo.size.height - verticalPadding * 2 - topBarHeight - headerHeight - 3,
                    108
                )
                let cellHeight = max(
                    (availableHeight - rowSpacing * CGFloat(periodCount - 1)) / CGFloat(periodCount),
                    5
                )

                VStack(alignment: .center, spacing: 3)
                {
                    HStack
                    {
                        Spacer()
                        Text("第 \(entry.currentWeek) 周")
                            .font(.system(size: 12, weight: .bold))
                        Spacer()
                    }
                    .frame(height: topBarHeight)

                    HStack(spacing: 0)
                    {
                        Text("\(entry.currentMonth)月")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: periodColumnWidth, height: headerHeight, alignment: .center)
                            .widgetAccentable()

                        ForEach(1 ... 7, id: \.self)
                        { day in
                            let isToday = day == entry.todayIndex
                            VStack(spacing: 1)
                            {
                                Text(weekdays[day - 1])
                                    .font(.system(size: 8, weight: isToday ? .bold : .medium))
                                    .foregroundColor(isToday ? .white : .secondary)
                                Text("\(entry.weekDates[safe: day - 1] ?? 0)")
                                    .font(.system(size: 6, weight: isToday ? .bold : .regular))
                                    .foregroundColor(isToday ? .white : .secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: headerHeight, maxHeight: headerHeight)
                            .background(isToday ? Capsule().fill(Color.blue) : Capsule().fill(Color.clear))
                            .widgetAccentable()
                        }
                    }
                    .padding(.horizontal, 4)
                    .background(
                        Capsule()
                            .fill(isAccentedMode ? Color.white.opacity(0.12) : Color.gray.opacity(0.08))
                    )
                    .clipShape(Capsule())

                    HStack(spacing: 0)
                    {
                        VStack(spacing: rowSpacing)
                        {
                            ForEach(1 ... periodCount, id: \.self)
                            { period in
                                let isCurrent = entry.currentPeriod == period
                                Text("\(period)")
                                    .font(.system(size: 7, weight: isCurrent ? .bold : .medium))
                                    .foregroundColor(isCurrent ? .white : .secondary)
                                    .frame(width: periodColumnWidth, height: cellHeight)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(isCurrent ? Color.blue : Color.clear)
                                    )
                                    .widgetAccentable()
                            }
                        }
                        .background(isAccentedMode ? Color.white.opacity(0.10) : Color.gray.opacity(0.08))
                        .clipShape(Capsule())
                        

                        HStack(spacing: columnSpacing)
                        {
                            ForEach(1 ... 7, id: \.self)
                            { day in
                                dayColumn(day: day, cellHeight: cellHeight, availableHeight: availableHeight)
                            }
                        }
                        .padding(.leading, 4.5)
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }

    @ViewBuilder
    private func backgroundImageView(in size: CGSize) -> some View
    {
        if let image = loadSharedBackgroundImage(filename: entry.backgroundFilename)
        {
            Group
            {
                if #available(iOS 18.0, *), isAccentedMode
                {
                    Image(uiImage: image)
                        .resizable()
                        .widgetAccentedRenderingMode(.accentedDesaturated)
                        .scaledToFill()
                }
                else
                {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .opacity(entry.backgroundOpacity)
        }
        else
        {
            (isAccentedMode ? Color.white.opacity(0.08) : Color.clear)
                .frame(width: size.width, height: size.height)
        }
    }

    private func loadSharedBackgroundImage(filename: String) -> UIImage?
    {
        guard !filename.isEmpty,
              let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetShared.appGroupID)
        else
        {
            return nil
        }
        let fileURL = dir.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    @ViewBuilder
    private func dayColumn(day: Int, cellHeight: CGFloat, availableHeight: CGFloat) -> some View
    {
        let dayCourses = resolveConflictsForDay(coursesForDay(day))
            .filter { $0.start <= periodCount && $0.endPeriod >= 1 }

        ZStack(alignment: .top)
        {
            VStack(spacing: rowSpacing)
            {
                ForEach(1 ... periodCount, id: \.self)
                { _ in
                    emptyCell(cellHeight: cellHeight)
                }
            }

            ForEach(dayCourses)
            { course in
                courseCell(course: course, cellHeight: cellHeight)
                    .offset(y: yOffset(for: course, cellHeight: cellHeight))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: availableHeight, alignment: .top)
    }

    private func coursesForDay(_ day: Int) -> [WidgetCourse]
    {
        entry.weeklyCourses.filter { $0.day == day }.sorted { $0.start < $1.start }
    }

    private func yOffset(for course: WidgetCourse, cellHeight: CGFloat) -> CGFloat
    {
        CGFloat(max(min(course.start, periodCount), 1) - 1) * (cellHeight + rowSpacing)
    }

    private func resolveConflictsForDay(_ courses: [WidgetCourse]) -> [WidgetCourse]
    {
        guard courses.count > 1 else { return courses }
        let sorted = courses.sorted { $0.start < $1.start }
        var groupID = Array(0 ..< sorted.count)

        func find(_ i: Int) -> Int
        {
            var idx = i
            while groupID[idx] != idx { idx = groupID[idx] }
            return idx
        }
        func union(_ i: Int, _ j: Int)
        {
            groupID[find(i)] = find(j)
        }
        func overlaps(_ a: WidgetCourse, _ b: WidgetCourse) -> Bool
        {
            a.start <= b.endPeriod && b.start <= a.endPeriod
        }
        for i in 0 ..< sorted.count
        {
            for j in (i + 1) ..< sorted.count
            {
                if overlaps(sorted[i], sorted[j]) { union(i, j) }
            }
        }

        var groups: [Int: [WidgetCourse]] = [:]
        for (idx, c) in sorted.enumerated()
        {
            groups[find(idx), default: []].append(c)
        }

        func winner(_ a: WidgetCourse, _ b: WidgetCourse) -> WidgetCourse
        {
            if a.step != b.step { return a.step > b.step ? a : b }
            return a.isManual ? b : a
        }

        var result: [WidgetCourse] = []
        for (_, group) in groups
        {
            result.append(group.reduce(group[0]) { winner($0, $1) })
        }
        return result
    }

    @ViewBuilder
    private func emptyCell(cellHeight: CGFloat) -> some View
    {
        RoundedRectangle(cornerRadius: 4)
            .fill(isAccentedMode ? Color.white.opacity(0.08) : Color.gray.opacity(0.14))
            .frame(height: cellHeight)
    }

    @ViewBuilder
    private func courseCell(course: WidgetCourse, cellHeight: CGFloat) -> some View
    {
        let start = max(course.start, 1)
        let end = min(course.endPeriod, periodCount)
        let span = max(end - start + 1, 1)
        let height = CGFloat(span) * cellHeight + CGFloat(max(span - 1, 0)) * rowSpacing

        VStack(spacing: 1)
        {
            Text(course.name)
                .font(.system(size: 8, weight: .bold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(course.room ?? " ")
                .font(.system(size:6, weight: .medium))
                .lineLimit(2)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        .padding(.horizontal, 1.5)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isAccentedMode ? Color.white.opacity(0.22) : courseColor(for: course).opacity(0.9))
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .widgetAccentable()
        
    }

    private func courseColor(for course: WidgetCourse) -> Color
    {
        if let hex = course.customColorHex, let custom = Color(hex: hex)
        {
            return custom
        }
        let colors: [Color] = [
            .blue, .green, .orange, .purple, .pink, .red, .yellow, .gray,
            .teal, .indigo, .cyan, .mint, .brown,
            Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.65, green: 0.35, blue: 0.88, alpha: 1) : UIColor(red: 0.5, green: 0.2, blue: 0.8, alpha: 1) }),
            Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.94, green: 0.45, blue: 0.60, alpha: 1) : UIColor(red: 0.9, green: 0.3, blue: 0.5, alpha: 1) }),
            Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.35, green: 0.70, blue: 0.50, alpha: 1) : UIColor(red: 0.2, green: 0.6, blue: 0.4, alpha: 1) }),
            Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.55, green: 0.78, blue: 0.92, alpha: 1) : UIColor(red: 0.4, green: 0.7, blue: 0.9, alpha: 1) }),
            Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.78, green: 0.60, blue: 0.92, alpha: 1) : UIColor(red: 0.7, green: 0.5, blue: 0.9, alpha: 1) }),
            Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.94, green: 0.68, blue: 0.50, alpha: 1) : UIColor(red: 0.9, green: 0.6, blue: 0.4, alpha: 1) }),
            Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.60, green: 0.85, blue: 0.68, alpha: 1) : UIColor(red: 0.5, green: 0.8, blue: 0.6, alpha: 1) }),
            Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.94, green: 0.60, blue: 0.68, alpha: 1) : UIColor(red: 0.9, green: 0.5, blue: 0.6, alpha: 1) }),
            Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.72, green: 0.52, blue: 0.78, alpha: 1) : UIColor(red: 0.6, green: 0.4, blue: 0.7, alpha: 1) }),
            Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.45, green: 0.62, blue: 0.78, alpha: 1) : UIColor(red: 0.3, green: 0.5, blue: 0.7, alpha: 1) }),
            Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.88, green: 0.68, blue: 0.42, alpha: 1) : UIColor(red: 0.8, green: 0.6, blue: 0.3, alpha: 1) }),
            Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.38, green: 0.48, blue: 0.65, alpha: 1) : UIColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 1) }),
            Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.45, green: 0.62, blue: 0.42, alpha: 1) : UIColor(red: 0.3, green: 0.5, blue: 0.3, alpha: 1) }),
            Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.75, green: 0.48, blue: 0.38, alpha: 1) : UIColor(red: 0.6, green: 0.3, blue: 0.2, alpha: 1) }),
            Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.68, green: 0.38, blue: 0.55, alpha: 1) : UIColor(red: 0.5, green: 0.2, blue: 0.4, alpha: 1) }),
            Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.38, green: 0.62, blue: 0.62, alpha: 1) : UIColor(red: 0.2, green: 0.5, blue: 0.5, alpha: 1) }),
            Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.65, green: 0.55, blue: 0.35, alpha: 1) : UIColor(red: 0.5, green: 0.4, blue: 0.2, alpha: 1) }),
            Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.58, green: 0.38, blue: 0.65, alpha: 1) : UIColor(red: 0.4, green: 0.2, blue: 0.5, alpha: 1) }),
            Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.75, green: 0.38, blue: 0.48, alpha: 1) : UIColor(red: 0.6, green: 0.2, blue: 0.3, alpha: 1) }),
        ]
        return colors[course.colorRandom % colors.count]
    }
}

struct ScheduleWidget: Widget
{
    let kind: String = "ScheduleWidget"

    var body: some WidgetConfiguration
    {
        StaticConfiguration(kind: kind, provider: Provider())
        { entry in
            if #available(iOS 17.0, *)
            {
                if loadCampusPassActive()
                {
                    ScheduleWidgetEntryView(entry: entry)
                        .containerBackground(.clear, for: .widget)
                }
                else
                {
                    Text("开通校园通行证后可用")
                }
                
            }
            else
            {
                ScheduleWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("课表")
        .description("完整显示当周课表")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
    
    //加载校园通行证是否有效
    private func loadCampusPassActive() -> Bool
    {
        let shared = UserDefaults(suiteName: WidgetShared.appGroupID)
        return shared?.bool(forKey: WidgetShared.campusPassActiveKey) ?? false
    }

}

extension Color
{
    init?(hex: String)
    {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
        let r = Double((v & 0xFF0000) >> 16) / 255.0
        let g = Double((v & 0x00FF00) >> 8) / 255.0
        let b = Double(v & 0x0000FF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}

private extension Array
{
    subscript(safe index: Int) -> Element?
    {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview(as: .systemLarge)
{
    ScheduleWidget()
} timeline: {
    SimpleEntry(
        date: .now,
        currentWeek: 8,
        currentMonth: 4,
        weekDates: [21, 22, 23, 24, 25, 26, 27],
        todayIndex: 4,
        currentPeriod: 9,
        weeklyCourses: [
            WidgetCourse(id: "1", name: "编译原理", day: 2, start: 3, step: 2, room: nil, teacher: nil, weekList: [8], weeks: nil, term: nil, colorRandom: 1, customColorHex: nil, isManual: false),
            WidgetCourse(id: "2", name: "智慧农业", day: 5, start: 9, step: 2, room: nil, teacher: nil, weekList: [8], weeks: nil, term: nil, colorRandom: 3, customColorHex: nil, isManual: false),
        ],
        backgroundFilename: "",
        backgroundOpacity: 0.2
    )
}
