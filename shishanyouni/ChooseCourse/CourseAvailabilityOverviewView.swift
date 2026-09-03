//
//  CourseAvailabilityOverviewView.swift
//  shishanyouni
//
//  已选课程的按周空闲度概览：周 × 星期 × 节次。
//

import Foundation
import SwiftUI

/// 从“已选科目”进入的课表占用概览。
/// 红色格子表示该周、该日、该节已有课程；灰色格子表示当前已选课程中没有安排。
struct CourseAvailabilityOverviewView: View
{
    private let semester: SelectedCourseSemester
    private let availability: CourseAvailabilityData

    @State private var selectedWeek: Int
    @State private var selectedSlot: CourseAvailabilitySlot?

    init(
        courses: [SelectedCourse],
        semester: SelectedCourseSemester,
        supplementarySchedules: [SelectedCourseScheduleEntry] = []
    )
    {
        let availability = CourseAvailabilityData(
            courses: courses,
            supplementarySchedules: supplementarySchedules
        )
        self.semester = semester
        self.availability = availability
        _selectedWeek = State(initialValue: availability.initialWeek)
    }

    var body: some View
    {
        ZStack
        {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView
            {
                VStack(spacing: 18)
                {
                    VStack(alignment: .leading, spacing: 5)
                    {
                        Text(semester.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("按周查看已选课程安排：红色为有课，灰色为空闲。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    weekSwitcher
                    availabilityGrid

                    HStack(spacing: 16)
                    {
                        AvailabilityLegend(color: .red, title: "已有课程")
                        AvailabilityLegend(color: .gray.opacity(0.32), title: "空闲")
                        Spacer()
                        Text("点按红色格子查看地点")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if !availability.hasBusySlot
                    {
                        VStack(spacing: 8)
                        {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("暂未识别到排课")
                                .font(.headline)
                            Text("当前已选课程没有可用于排课的上课时间。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }

                    if !availability.unparsedCourseNames.isEmpty
                    {
                        Label {
                            Text("以下课程的上课时间格式暂无法识别，未计入网格：\(availability.unparsedCourseNames.joined(separator: "、"))")
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("空闲度概览")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .sheet(item: $selectedSlot)
        { slot in
            CourseAvailabilitySlotDetailView(slot: slot)
        }
    }

    private var weekSwitcher: some View
    {
        HStack
        {
            Button
            {
                selectedWeek -= 1
            }
            label:
            {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.semibold))
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.bordered)
            .disabled(selectedWeek <= availability.weekRange.lowerBound)
            .accessibilityLabel("上一周")

            Spacer()

            VStack(spacing: 2)
            {
                Text("第 \(selectedWeek) 周")
                    .font(.title3.weight(.bold))
                Text("共 \(availability.weekRange.upperBound) 周")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button
            {
                selectedWeek += 1
            }
            label:
            {
                Image(systemName: "chevron.right")
                    .font(.headline.weight(.semibold))
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.bordered)
            .disabled(selectedWeek >= availability.weekRange.upperBound)
            .accessibilityLabel("下一周")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    private var availabilityGrid: some View
    {
        VStack(alignment: .leading, spacing: 12)
        {
            Text("第 \(selectedWeek) 周课表")
                .font(.headline.weight(.semibold))

            Grid(horizontalSpacing: 4, verticalSpacing: 4)
            {
                GridRow
                {
                    Color.clear
                        .frame(width: 24, height: 20)

                    ForEach(Array(Self.weekdayTitles.enumerated()), id: \.offset)
                    { _, title in
                        Text(title)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                ForEach(1 ... CourseAvailabilityData.periodCount, id: \.self)
                { period in
                    GridRow
                    {
                        Text("\(period)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                            .accessibilityLabel("第 \(period) 节")

                        ForEach(1 ... CourseAvailabilityData.weekdayCount, id: \.self)
                        { weekday in
                            availabilityCell(weekday: weekday, period: period)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    @ViewBuilder
    private func availabilityCell(weekday: Int, period: Int) -> some View
    {
        let entries = availability.entries(week: selectedWeek, weekday: weekday, period: period)

        if entries.isEmpty
        {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.gray.opacity(0.22))
                .frame(height: 29)
                .accessibilityLabel("第 \(selectedWeek) 周，\(Self.weekdayTitles[weekday - 1])，第 \(period) 节，空闲")
        }
        else
        {
            Button
            {
                selectedSlot = CourseAvailabilitySlot(
                    week: selectedWeek,
                    weekday: weekday,
                    period: period,
                    entries: entries
                )
            }
            label:
            {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.red)
                    .overlay
                    {
                        if entries.count > 1
                        {
                            Text("\(entries.count)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(height: 29)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("第 \(selectedWeek) 周，\(Self.weekdayTitles[weekday - 1])，第 \(period) 节，有 \(entries.count) 门课程")
        }
    }

    private static let weekdayTitles = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
}

private struct AvailabilityLegend: View
{
    let color: Color
    let title: String

    var body: some View
    {
        HStack(spacing: 5)
        {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 14, height: 14)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// 与一个红色格子绑定的课程详情；矩阵只负责布尔占用，详情单独保存以供用户核对地点。
private struct CourseAvailabilitySlot: Identifiable
{
    let week: Int
    let weekday: Int
    let period: Int
    let entries: [CourseAvailabilityEntry]

    var id: String { "\(week)-\(weekday)-\(period)" }
}

private struct CourseAvailabilitySlotDetailView: View
{
    @Environment(\.dismiss) private var dismiss

    let slot: CourseAvailabilitySlot

    var body: some View
    {
        NavigationStack
        {
            List
            {
                Section
                {
                    Text("第 \(slot.week) 周 · \(Self.weekdayTitles[slot.weekday - 1]) · 第 \(slot.period) 节")
                        .font(.headline)
                }

                Section("课程与地点")
                {
                    ForEach(slot.entries)
                    { entry in
                        VStack(alignment: .leading, spacing: 8)
                        {
                            Text(entry.courseName)
                                .font(.headline)

                            if let teachingClassName = entry.teachingClassName
                            {
                                Text(teachingClassName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Label(entry.timeText, systemImage: "calendar")
                            Label(entry.location, systemImage: "mappin.and.ellipse")

                            if let teacher = entry.teacher
                            {
                                Label(teacher, systemImage: "person.fill")
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("课程详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar
            {
                ToolbarItem(placement: .confirmationAction)
                {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private static let weekdayTitles = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
}

/// 课表占用数据。
/// `occupied[week][weekday][period]` 等价于 C++ 的 `vector<vector<vector<bool>>>`：
/// 第一维是周数，第二维是星期（周一为 0），第三维是节次（第 1 节为 0）。
private struct CourseAvailabilityData
{
    static let weekdayCount = 7
    static let periodCount = 12
    private static let minimumWeekCount = 20

    let occupied: [[[Bool]]]
    private let slotEntries: [[[[CourseAvailabilityEntry]]]]
    let weekRange: ClosedRange<Int>
    let unparsedCourseNames: [String]

    init(
        courses: [SelectedCourse],
        supplementarySchedules: [SelectedCourseScheduleEntry] = []
    )
    {
        var occurrences: [CourseAvailabilityOccurrence] = []
        var unparsedCourseNames = Set<String>()
        var seenSchedules = Set<String>()

        for course in courses
        {
            let schedules = course.availabilitySchedules.filter
            {
                seenSchedules.insert($0.id).inserted
            }
            let parsed = schedules.flatMap
            {
                CourseScheduleParser.occurrences(from: $0)
            }
            if parsed.isEmpty, !schedules.isEmpty
            {
                unparsedCourseNames.insert(course.courseName)
            }
            occurrences.append(contentsOf: parsed)
        }

        for schedule in supplementarySchedules where seenSchedules.insert(schedule.id).inserted
        {
            let parsed = CourseScheduleParser.occurrences(from: schedule)
            if parsed.isEmpty
            {
                unparsedCourseNames.insert(schedule.courseName)
            }
            occurrences.append(contentsOf: parsed)
        }

        let maximumWeek = max(
            Self.minimumWeekCount,
            occurrences.flatMap(\.weeks).max() ?? 1
        )
        let range = 1 ... maximumWeek
        weekRange = range

        var entries = Array(
            repeating: Array(
                repeating: Array(repeating: [CourseAvailabilityEntry](), count: Self.periodCount),
                count: Self.weekdayCount
            ),
            count: maximumWeek
        )

        for occurrence in occurrences
        {
            for week in occurrence.weeks where range.contains(week)
            {
                for weekday in occurrence.weekdays where (1 ... Self.weekdayCount).contains(weekday)
                {
                    for period in occurrence.periods where (1 ... Self.periodCount).contains(period)
                    {
                        let index = (week - 1, weekday - 1, period - 1)
                        if !entries[index.0][index.1][index.2].contains(occurrence.entry)
                        {
                            entries[index.0][index.1][index.2].append(occurrence.entry)
                        }
                    }
                }
            }
        }

        slotEntries = entries
        occupied = entries.map
        { week in
            week.map
            { weekday in
                weekday.map { !$0.isEmpty }
            }
        }
        self.unparsedCourseNames = unparsedCourseNames.sorted()
    }

    var initialWeek: Int { weekRange.lowerBound }

    var hasBusySlot: Bool
    {
        occupied.contains
        { week in
            week.contains
            { weekday in
                weekday.contains(true)
            }
        }
    }

    func entries(week: Int, weekday: Int, period: Int) -> [CourseAvailabilityEntry]
    {
        guard weekRange.contains(week),
              (1 ... Self.weekdayCount).contains(weekday),
              (1 ... Self.periodCount).contains(period)
        else { return [] }

        return slotEntries[week - 1][weekday - 1][period - 1]
    }
}

private struct CourseAvailabilityOccurrence
{
    let weeks: [Int]
    let weekdays: [Int]
    let periods: [Int]
    let entry: CourseAvailabilityEntry
}

private struct CourseAvailabilityEntry: Identifiable, Hashable
{
    let id: String
    let courseName: String
    let teachingClassName: String?
    let teacher: String?
    let timeText: String
    let location: String
}

/// 教务系统的 `sksj` 是展示用中文字符串，例如：
/// `星期二第1-2节{10-15周}<br/>星期四第3-4节{3-4周,6-11周}`。
/// 这里把它转为周、星期、节次的离散坐标；未能确认的文本不会臆测成有课。
private enum CourseScheduleParser
{
    private static let defaultSemesterWeeks = 20
    private static let weekdayMap = ["一": 1, "二": 2, "三": 3, "四": 4, "五": 5, "六": 6, "日": 7, "天": 7]

    static func occurrences(from schedule: SelectedCourseScheduleEntry) -> [CourseAvailabilityOccurrence]
    {
        let timeLines = scheduleLines(from: schedule.classTime)
        let locations = scheduleLines(from: schedule.displayLocation ?? "")
        var occurrences: [CourseAvailabilityOccurrence] = []

        for (lineIndex, timeLine) in timeLines.enumerated()
        {
            guard let coordinate = coordinate(from: timeLine) else { continue }
            let location = location(for: lineIndex, locations: locations)

            for weekday in coordinate.weekdays
            {
                let entry = CourseAvailabilityEntry(
                    id: "\(schedule.id)-\(lineIndex)-\(weekday)",
                    courseName: schedule.courseName,
                    teachingClassName: schedule.displayTeachingClassName,
                    teacher: schedule.teacher,
                    timeText: timeLine,
                    location: location
                )
                occurrences.append(
                    CourseAvailabilityOccurrence(
                        weeks: coordinate.weeks,
                        weekdays: [weekday],
                        periods: coordinate.periods,
                        entry: entry
                    )
                )
            }
        }
        return occurrences
    }

    private static func scheduleLines(from text: String) -> [String]
    {
        let normalized = text.replacingOccurrences(
            of: #"<br\s*/?>"#,
            with: "\n",
            options: [.regularExpression, .caseInsensitive]
        )
        return normalized
            .components(separatedBy: .newlines)
            .flatMap { $0.components(separatedBy: CharacterSet(charactersIn: ";；")) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "--" }
    }

    private static func location(for index: Int, locations: [String]) -> String
    {
        guard !locations.isEmpty else { return "地点待定" }
        // 一个地点对应多个时段时，沿用最后一个有效地点，避免把它错误留空。
        return locations[min(index, locations.count - 1)]
    }

    private static func coordinate(from text: String) -> (weeks: [Int], weekdays: [Int], periods: [Int])?
    {
        let weekdays = captureGroups(#"(?:星期|周)([一二三四五六日天])"#, in: text)
            .compactMap { weekdayMap[$0] }
            .uniqueSorted()
        let periods = captureGroups(#"(?:第\s*)?([0-9０-９,，、\-—–~～至到\s]+)节"#, in: text)
            .flatMap(integerRanges)
            .filter { (1 ... CourseAvailabilityData.periodCount).contains($0) }
            .uniqueSorted()

        guard !weekdays.isEmpty, !periods.isEmpty else { return nil }
        return (weeks: weeks(in: text), weekdays: weekdays, periods: periods)
    }

    private static func weeks(in text: String) -> [Int]
    {
        let normalized = normalizeNumbers(in: text)
        // 每个周次片段都可能有自己的单双周标记，例如
        // `4-6周(双),7-9周(单)`；必须逐片段过滤，不能对整行做全局判断。
        let segmentPattern = #"([0-9]+(?:\s*[-~至到]\s*[0-9]+)?)\s*周\s*(?:[\(（]\s*(单|双)\s*周?\s*[\)）])?"#
        var explicitWeeks: [Int] = []
        if let expression = try? NSRegularExpression(pattern: segmentPattern)
        {
            let searchRange = NSRange(normalized.startIndex ..< normalized.endIndex, in: normalized)
            for match in expression.matches(in: normalized, range: searchRange)
            {
                guard match.numberOfRanges > 1,
                      let weeksRange = Range(match.range(at: 1), in: normalized)
                else { continue }

                var segmentWeeks = integerRanges(String(normalized[weeksRange]))
                if match.numberOfRanges > 2,
                   let parityRange = Range(match.range(at: 2), in: normalized)
                {
                    let parity = String(normalized[parityRange])
                    if parity == "单"
                    {
                        segmentWeeks = segmentWeeks.filter { !$0.isMultiple(of: 2) }
                    }
                    else if parity == "双"
                    {
                        segmentWeeks = segmentWeeks.filter { $0.isMultiple(of: 2) }
                    }
                }
                explicitWeeks.append(contentsOf: segmentWeeks)
            }
        }

        let validWeeks = explicitWeeks.filter { $0 > 0 && $0 <= 30 }.uniqueSorted()
        if !validWeeks.isEmpty
        {
            return validWeeks
        }

        var weeks = Array(1 ... defaultSemesterWeeks)
        // 没有显式片段时，兼容旧接口的“单周 / 双周”整行标记；混合标记不做猜测。
        let hasSingle = normalized.range(of: #"单\s*周|[\(（]\s*单\s*周?\s*[\)）]"#, options: .regularExpression) != nil
        let hasDouble = normalized.range(of: #"双\s*周|[\(（]\s*双\s*周?\s*[\)）]"#, options: .regularExpression) != nil
        if hasSingle, !hasDouble
        {
            weeks = weeks.filter { !$0.isMultiple(of: 2) }
        }
        else if hasDouble, !hasSingle
        {
            weeks = weeks.filter { $0.isMultiple(of: 2) }
        }
        return weeks
    }

    private static func captureGroups(_ pattern: String, in text: String) -> [String]
    {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex ..< text.endIndex, in: text)
        return expression.matches(in: text, range: range).compactMap
        { match in
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: text)
            else { return nil }
            return String(text[range])
        }
    }

    /// 把 `3-4、6、8-10` 这样的范围文本展开成离散数字。
    private static func integerRanges(_ rawValue: String) -> [Int]
    {
        let normalized = normalizeNumbers(in: rawValue)
        return normalized
            .split(whereSeparator: { $0 == "," || $0 == "，" || $0 == "、" })
            .flatMap
            { component -> [Int] in
                let text = String(component)
                let values = captureGroups(#"(\d+)"#, in: text).compactMap(Int.init)
                guard !values.isEmpty else { return [] }

                if text.range(of: #"[-~至到]"#, options: .regularExpression) != nil,
                   values.count >= 2
                {
                    return Array(min(values[0], values[1]) ... max(values[0], values[1]))
                }
                return values
            }
    }

    private static func normalizeNumbers(in text: String) -> String
    {
        text
            .replacingOccurrences(of: "０", with: "0")
            .replacingOccurrences(of: "１", with: "1")
            .replacingOccurrences(of: "２", with: "2")
            .replacingOccurrences(of: "３", with: "3")
            .replacingOccurrences(of: "４", with: "4")
            .replacingOccurrences(of: "５", with: "5")
            .replacingOccurrences(of: "６", with: "6")
            .replacingOccurrences(of: "７", with: "7")
            .replacingOccurrences(of: "８", with: "8")
            .replacingOccurrences(of: "９", with: "9")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "～", with: "-")
    }
}

private extension Array where Element == Int
{
    func uniqueSorted() -> [Int]
    {
        Array(Set(self)).sorted()
    }
}
