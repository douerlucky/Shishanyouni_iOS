//
//  CurriculumSharedWidget.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/9/11.
//

import Foundation

/// 课表 Widget 专属的课程展示模型。
///
/// `Course` 仍然是主 App 的业务模型；主 App 写入 App Group 时，
/// 只把 Widget 画课表需要的字段转换成这里的 `WidgetCourse`。
/// 因此 Widget 不会依赖主 App 的业务字段，也不会反向修改 `Course`。
struct WidgetCourse: Codable, Identifiable
{
    let id: String
    let name: String
    let day: Int
    let start: Int
    let step: Int
    let room: String?
    let weekList: [Int]
    let colorRandom: Int
    let customColorHex: String?
    let isManual: Bool

    var endPeriod: Int { start + step - 1 }
}

/// 课表 Widget 的只含 Foundation 的共享存储接口。
/// WidgetKit 刷新动作不放这里，由 App 侧的 `CurriculumWidgetSync` 负责触发。
enum CurriculumWidgetShared
{
    static func saveCourses(_ courses: [WidgetCourse])
    {
        guard let data = try? JSONEncoder().encode(courses) else { return }
        WidgetAppGroup.defaults?.set(data, forKey: WidgetAppGroup.Key.savedCourses)
    }

    static func loadCourses() -> [WidgetCourse]
    {
        guard let data = WidgetAppGroup.defaults?.data(forKey: WidgetAppGroup.Key.savedCourses) else
        {
            return []
        }
        return (try? JSONDecoder().decode([WidgetCourse].self, from: data)) ?? []
    }

    static func clearCourses()
    {
        WidgetAppGroup.defaults?.removeObject(forKey: WidgetAppGroup.Key.savedCourses)
    }

    static func saveSemesterStartTimestamp(_ timestamp: Double)
    {
        WidgetAppGroup.defaults?.set(timestamp, forKey: WidgetAppGroup.Key.semesterStartTimestamp)
    }

    static func semesterStartTimestamp() -> Double?
    {
        WidgetAppGroup.defaults?.object(forKey: WidgetAppGroup.Key.semesterStartTimestamp) as? Double
    }

    static func saveCurrentWeek(_ week: Int)
    {
        WidgetAppGroup.defaults?.set(week, forKey: WidgetAppGroup.Key.currentWeek)
    }

    static func currentWeek() -> Int
    {
        max(WidgetAppGroup.defaults?.integer(forKey: WidgetAppGroup.Key.currentWeek) ?? 1, 1)
    }

    /// 按课表的周一作为每周第一天，计算某个日期属于第几教学周。
    static func calculatedWeek(at date: Date) -> Int?
    {
        guard let timestamp = WidgetAppGroup.defaults?.object(forKey: WidgetAppGroup.Key.semesterStartTimestamp) as? Double,
              timestamp > 0
        else
        {
            return nil
        }

        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let semesterStart = Date(timeIntervalSince1970: timestamp)
        let startComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: semesterStart)
        let currentComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)

        guard let startMonday = calendar.date(from: startComponents),
              let currentMonday = calendar.date(from: currentComponents)
        else
        {
            return nil
        }

        let difference = calendar.dateComponents([.weekOfYear], from: startMonday, to: currentMonday)
        return max((difference.weekOfYear ?? 0) + 1, 1)
    }

    static func backgroundMetadata() -> (filename: String, opacity: Double)
    {
        let defaults = WidgetAppGroup.defaults
        let filename = defaults?.string(forKey: WidgetAppGroup.Key.backgroundImageFilename) ?? ""
        let opacity = defaults?.object(forKey: WidgetAppGroup.Key.backgroundOpacity) as? Double ?? 0.2
        return (filename, opacity)
    }

    static func saveBackgroundMetadata(filename: String, opacity: Double)
    {
        let defaults = WidgetAppGroup.defaults
        defaults?.set(filename, forKey: WidgetAppGroup.Key.backgroundImageFilename)
        defaults?.set(opacity, forKey: WidgetAppGroup.Key.backgroundOpacity)
    }

    static func clearBackgroundMetadata()
    {
        WidgetAppGroup.defaults?.removeObject(forKey: WidgetAppGroup.Key.backgroundImageFilename)
        WidgetAppGroup.defaults?.removeObject(forKey: WidgetAppGroup.Key.backgroundOpacity)
    }

}
