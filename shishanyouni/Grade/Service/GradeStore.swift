// 本功能的唯一缓存入口；存储键与现有版本保持兼容。
import Foundation

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
