//
//  AcademicStores.swift
//  shishanyouni
//
//  课表、考试和成绩的本地缓存。
//

import Foundation

/// 统一保存查询结果及其更新时间，避免业务层分别维护两个不一致的 UserDefaults key。
private struct QueryCacheEnvelope<Item: Codable>: Codable
{
    let items: [Item]
    let updatedAt: Date
}

/// 课表数据的唯一读写入口，同时负责通知下节课和首页刷新。
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

/// 考试查询缓存；key 保留旧格式，确保已缓存数据无需迁移。
final class ExamStore
{
    static let shared = ExamStore()

    private let latestKey = "exam_cache_latest_v1"

    private init() {}

    private func cacheKey(username: String, year: String, term: String, source: ExamQuerySource) -> String
    {
        "exam_cache_\(username)_\(year)_\(term)_\(source.rawValue)"
    }

    func saveExams(_ exams: [Exam], username: String, year: String, term: String, source: ExamQuerySource)
    {
        let envelope = QueryCacheEnvelope(items: exams, updatedAt: Date())
        guard let data = try? JSONEncoder().encode(envelope) else { return }

        UserDefaults.standard.set(data, forKey: cacheKey(username: username, year: year, term: term, source: source))
        UserDefaults.standard.set(data, forKey: latestKey)
        NotificationCenter.default.post(name: .homeNextEventsDidChange, object: nil)
    }

    func loadExams(username: String, year: String, term: String, source: ExamQuerySource) -> [Exam]
    {
        guard let data = UserDefaults.standard.data(forKey: cacheKey(username: username, year: year, term: term, source: source)),
              let envelope = try? JSONDecoder().decode(QueryCacheEnvelope<Exam>.self, from: data) else { return [] }
        return envelope.items
    }

    func lastUpdatedAt(username: String, year: String, term: String, source: ExamQuerySource) -> Date?
    {
        guard let data = UserDefaults.standard.data(forKey: cacheKey(username: username, year: year, term: term, source: source)),
              let envelope = try? JSONDecoder().decode(QueryCacheEnvelope<Exam>.self, from: data) else { return nil }
        return envelope.updatedAt
    }

    func loadLatestExams() -> [Exam]
    {
        guard let data = UserDefaults.standard.data(forKey: latestKey),
              let envelope = try? JSONDecoder().decode(QueryCacheEnvelope<Exam>.self, from: data) else { return [] }
        return envelope.items
    }
}

/// 成绩查询缓存；保留不含数据源后缀的旧 key 作为兼容回退。
final class GradeStore
{
    static let shared = GradeStore()

    private init() {}

    private func cacheKey(
        username: String,
        year: String,
        term: String,
        source: GradeQuerySource
    ) -> String
    {
        "grade_cache_\(username)_\(year)_\(term)_\(source.rawValue)"
    }

    private func legacyCacheKey(username: String, year: String, term: String) -> String
    {
        "grade_cache_\(username)_\(year)_\(term)"
    }

    func saveGrades(_ grades: [Grade], username: String, year: String, term: String)
    {
        saveGrades(
            grades,
            username: username,
            year: year,
            term: term,
            source: .shishanyouni
        )
    }

    func saveGrades(
        _ grades: [Grade],
        username: String,
        year: String,
        term: String,
        source: GradeQuerySource
    )
    {
        let envelope = QueryCacheEnvelope(items: grades, updatedAt: Date())
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        UserDefaults.standard.set(
            data,
            forKey: cacheKey(username: username, year: year, term: term, source: source)
        )
    }

    func loadGrades(username: String, year: String, term: String) -> [Grade]
    {
        loadGrades(
            username: username,
            year: year,
            term: term,
            source: .shishanyouni
        )
    }

    func loadGrades(
        username: String,
        year: String,
        term: String,
        source: GradeQuerySource
    ) -> [Grade]
    {
        let data = UserDefaults.standard.data(
            forKey: cacheKey(username: username, year: year, term: term, source: source)
        ) ?? (source == .shishanyouni
            ? UserDefaults.standard.data(forKey: legacyCacheKey(username: username, year: year, term: term))
            : nil)

        guard let data,
              let envelope = try? JSONDecoder().decode(QueryCacheEnvelope<Grade>.self, from: data) else { return [] }
        return envelope.items
    }

    func lastUpdatedAt(username: String, year: String, term: String) -> Date?
    {
        lastUpdatedAt(
            username: username,
            year: year,
            term: term,
            source: .shishanyouni
        )
    }

    func lastUpdatedAt(
        username: String,
        year: String,
        term: String,
        source: GradeQuerySource
    ) -> Date?
    {
        let data = UserDefaults.standard.data(
            forKey: cacheKey(username: username, year: year, term: term, source: source)
        ) ?? (source == .shishanyouni
            ? UserDefaults.standard.data(forKey: legacyCacheKey(username: username, year: year, term: term))
            : nil)

        guard let data,
              let envelope = try? JSONDecoder().decode(QueryCacheEnvelope<Grade>.self, from: data) else { return nil }
        return envelope.updatedAt
    }
}
