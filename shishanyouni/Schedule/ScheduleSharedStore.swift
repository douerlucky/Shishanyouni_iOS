//
//  ScheduleSharedStore.swift
//  shishanyouni
//
//  Shared storage bridge between App and Widget.
//

import Foundation
import WidgetKit

enum ScheduleSharedStore
{
    static let appGroupID = "group.cn.edu.hzau.shishanyouni"
    static let widgetKind = "ScheduleWidget"

    static let savedCoursesKey = "saved_courses"
    static let semesterStartTimestampKey = "semesterStartDateTimestamp"
    static let currentWeekKey = "schedule_current_week"
    static let backgroundImageFilenameKey = "scheduleBackgroundImageFilename"
    static let backgroundOpacityKey = "scheduleBackgroundOpacity"

    static var sharedDefaults: UserDefaults?
    {
        UserDefaults(suiteName: appGroupID)
    }

    static func saveCourses(_ courses: [Course])
    {
        do
        {
            let data = try JSONEncoder().encode(courses)
            UserDefaults.standard.set(data, forKey: savedCoursesKey) // 兼容旧逻辑
            sharedDefaults?.set(data, forKey: savedCoursesKey) // Widget 读取
            reloadWidget()
        }
        catch
        {
            print("❌ shared save courses failed: \(error)")
        }
    }

    static func loadCourses() -> [Course]
    {
        // 优先读取共享存储
        if let sharedData = sharedDefaults?.data(forKey: savedCoursesKey),
           let courses = try? JSONDecoder().decode([Course].self, from: sharedData)
        {
            return courses
        }

        // 兼容历史数据：从 standard 迁移到共享存储
        if let localData = UserDefaults.standard.data(forKey: savedCoursesKey),
           let courses = try? JSONDecoder().decode([Course].self, from: localData)
        {
            sharedDefaults?.set(localData, forKey: savedCoursesKey)
            return courses
        }

        return []
    }

    static func clearCourses()
    {
        UserDefaults.standard.removeObject(forKey: savedCoursesKey)
        sharedDefaults?.removeObject(forKey: savedCoursesKey)
        reloadWidget()
    }

    static func saveSemesterStartTimestamp(_ timestamp: Double)
    {
        UserDefaults.standard.set(timestamp, forKey: semesterStartTimestampKey)
        sharedDefaults?.set(timestamp, forKey: semesterStartTimestampKey)
        reloadWidget()
    }

    static func loadSemesterStartTimestamp() -> Double?
    {
        if let ts = sharedDefaults?.object(forKey: semesterStartTimestampKey) as? Double
        {
            return ts
        }
        if let ts = UserDefaults.standard.object(forKey: semesterStartTimestampKey) as? Double
        {
            sharedDefaults?.set(ts, forKey: semesterStartTimestampKey)
            return ts
        }
        return nil
    }

    static func saveCurrentWeek(_ week: Int)
    {
        UserDefaults.standard.set(week, forKey: currentWeekKey)
        sharedDefaults?.set(week, forKey: currentWeekKey)
        reloadWidget()
    }

    static func reloadWidget()
    {
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }

    static func sharedContainerURL() -> URL?
    {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    static func saveBackgroundMeta(filename: String, opacity: Double)
    {
        UserDefaults.standard.set(filename, forKey: backgroundImageFilenameKey)
        UserDefaults.standard.set(opacity, forKey: backgroundOpacityKey)
        sharedDefaults?.set(filename, forKey: backgroundImageFilenameKey)
        sharedDefaults?.set(opacity, forKey: backgroundOpacityKey)
        reloadWidget()
    }

    static func clearBackgroundMeta()
    {
        UserDefaults.standard.removeObject(forKey: backgroundImageFilenameKey)
        sharedDefaults?.removeObject(forKey: backgroundImageFilenameKey)
        reloadWidget()
    }
}
