import Foundation
import SwiftUI

/// 教务系统的 `sksj` 是展示用中文字符串，例如：
/// `星期二第1-2节{10-15周}<br/>星期四第3-4节{3-4周,6-11周}`。
/// 这里把它转为周、星期、节次的离散坐标；未能确认的文本不会臆测成有课。
enum CourseScheduleParser
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
