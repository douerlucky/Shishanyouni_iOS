// 本功能的唯一缓存入口；存储键与现有版本保持兼容。
import Foundation

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
