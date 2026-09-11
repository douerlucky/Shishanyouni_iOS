//
//  CurriculumWidgetSync.swift
//  shishanyouni
//
//  主 App 到课表 Widget 的同步器。
//

import Foundation
import WidgetKit

/// 只属于主 App Target 的课表 Widget 同步入口。
///
/// `Course` 是 App 的完整业务模型，`WidgetCourse` 是 Widget 的精简展示模型。
/// 这个类型负责两者之间的转换、历史本地数据兼容，以及刷新 Widget；
/// 不把这些 App 专属职责放入 `SharedWidget`。
enum CurriculumWidgetSync
{
    private static let widgetKind = WidgetAppGroup.Kind.curriculum

    //保存课表
    static func saveCourses(_ courses: [Course])
    {
        do
        {
            // 主 App 保留完整模型，避免 Widget 的精简 DTO 丢失编辑所需字段。
            let data = try JSONEncoder().encode(courses)
            UserDefaults.standard.set(data, forKey: WidgetAppGroup.Key.savedCourses)

            // App Group 只存 Widget 所需字段，Extension 不依赖 App 的 Course 模型。
            CurriculumWidgetShared.saveCourses(courses.map(widgetCourse(from:)))
            reloadWidget() //刷新课表 Widget
        }
        catch
        {
            print("❌ 课表保存失败: \(error)")
        }
    }

    //读取课表
    static func loadCourses() -> [Course]
    {
        // 主 App 的完整 Course 才是真源。Widget DTO 故意省略 assessmentMethod 等
        // App 专属字段，因此绝不能反过来覆盖主 App 的完整课程数据。
        if let localData = UserDefaults.standard.data(forKey: WidgetAppGroup.Key.savedCourses),
           let courses = try? JSONDecoder().decode([Course].self, from: localData)
        {
            return courses
        }

        // 仅在升级后主 App 还没有本地完整课表时，才从 App Group 数据兜底迁移。
        if let sharedData = WidgetAppGroup.defaults?.data(forKey: WidgetAppGroup.Key.savedCourses),
           let courses = decodeCoursesFromSharedData(sharedData)
        {
            // 无论读到的是历史完整 Course，还是当前的 WidgetCourse，
            // 都重新编码成主 App 的完整 Course，避免 Widget 展示模型反向污染业务存储。
            if let localData = try? JSONEncoder().encode(courses)
            {
                UserDefaults.standard.set(localData, forKey: WidgetAppGroup.Key.savedCourses)
            }
            CurriculumWidgetShared.saveCourses(courses.map(widgetCourse(from:)))
            return courses
        }

        return []
    }

    /// 兼容历史 App Group 中可能保存的完整 `Course` 或 `WidgetCourse`。
    private static func decodeCoursesFromSharedData(_ data: Data) -> [Course]?
    {
        if let courses = try? JSONDecoder().decode([Course].self, from: data)
        {
            return courses
        }

        guard let widgetCourses = try? JSONDecoder().decode([WidgetCourse].self, from: data) else
        {
            return nil
        }

        return widgetCourses.map
        {
            Course(
                id: $0.id,
                name: $0.name,
                day: $0.day,
                start: $0.start,
                step: $0.step,
                room: $0.room,
                teacher: nil,
                weekList: $0.weekList,
                weeks: nil,
                term: nil,
                colorRandom: $0.colorRandom,
                customColorHex: $0.customColorHex,
                isManual: $0.isManual,
                assessmentMethod: nil
            )
        }
    }

    static func clearCourses()
    {
        UserDefaults.standard.removeObject(forKey: WidgetAppGroup.Key.savedCourses)
        CurriculumWidgetShared.clearCourses()
        reloadWidget()
    }

    static func saveSemesterStartTimestamp(_ timestamp: Double)
    {
        UserDefaults.standard.set(timestamp, forKey: WidgetAppGroup.Key.semesterStartTimestamp)
        CurriculumWidgetShared.saveSemesterStartTimestamp(timestamp)
        reloadWidget()
    }

    static func loadSemesterStartTimestamp() -> Double?
    {
        if let timestamp = CurriculumWidgetShared.semesterStartTimestamp()
        {
            return timestamp
        }

        if let timestamp = UserDefaults.standard.object(forKey: WidgetAppGroup.Key.semesterStartTimestamp) as? Double
        {
            CurriculumWidgetShared.saveSemesterStartTimestamp(timestamp)
            return timestamp
        }

        return nil
    }

    static func saveCurrentWeek(_ week: Int)
    {
        UserDefaults.standard.set(week, forKey: WidgetAppGroup.Key.currentWeek)
        CurriculumWidgetShared.saveCurrentWeek(week)
        reloadWidget()
    }

    /// 背景图片本体放在 App Group 容器；元数据仍通过共享 DTO 存储。
    static func appGroupContainerURL() -> URL?
    {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetAppGroup.identifier)
    }

    static func saveBackgroundMetadata(filename: String, opacity: Double)
    {
        UserDefaults.standard.set(filename, forKey: WidgetAppGroup.Key.backgroundImageFilename)
        UserDefaults.standard.set(opacity, forKey: WidgetAppGroup.Key.backgroundOpacity)
        CurriculumWidgetShared.saveBackgroundMetadata(filename: filename, opacity: opacity)
        reloadWidget()
    }

    static func clearBackgroundMetadata()
    {
        // 保持原有行为：主 App 清空文件名；App Group 同时清空文件名和透明度。
        UserDefaults.standard.removeObject(forKey: WidgetAppGroup.Key.backgroundImageFilename)
        CurriculumWidgetShared.clearBackgroundMetadata()
        reloadWidget()
    }

    static func reloadWidget()
    {
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }

    private static func widgetCourse(from course: Course) -> WidgetCourse
    {
        WidgetCourse(
            id: course.id,
            name: course.name,
            day: course.day,
            start: course.start,
            step: course.step,
            room: course.room,
            weekList: course.weekList,
            colorRandom: course.colorRandom,
            customColorHex: course.customColorHex,
            isManual: course.isManual
        )
    }
}
