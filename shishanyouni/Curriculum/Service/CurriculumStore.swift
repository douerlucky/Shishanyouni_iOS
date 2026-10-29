// 本功能的唯一缓存入口；存储键与现有版本保持兼容。
import Foundation

final class CurriculumStore
{
    static let shared = CurriculumStore()

    private let lastUpdatedKey = "curriculum_last_updated"

    private init() {}

    func saveCourses(_ courses: [Course], semesterStart: Date?)
    {
        CurriculumWidgetSync.saveCourses(courses)
        if let semesterStart
        {
            CurriculumWidgetSync.saveSemesterStartTimestamp(semesterStart.timeIntervalSince1970)
        }
        NextCourseSync.sync(
            courses: courses,
            semesterStart: semesterStart ?? loadSemesterStartDate()
        )
        UserDefaults.standard.set(Date(), forKey: lastUpdatedKey)
        NotificationCenter.default.post(name: .homeNextEventsDidChange, object: nil)
    }

    func loadCourses() -> [Course]
    {
        CurriculumWidgetSync.loadCourses()
    }

    func loadSemesterStartDate() -> Date?
    {
        guard let timestamp = CurriculumWidgetSync.loadSemesterStartTimestamp(), timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    func saveSemesterStartTimestamp(_ timestamp: Double)
    {
        CurriculumWidgetSync.saveSemesterStartTimestamp(timestamp)
        NextCourseSync.sync()
        UserDefaults.standard.set(Date(), forKey: lastUpdatedKey)
        NotificationCenter.default.post(name: .homeNextEventsDidChange, object: nil)
    }

    func lastUpdatedAt() -> Date?
    {
        UserDefaults.standard.object(forKey: lastUpdatedKey) as? Date
    }
}
