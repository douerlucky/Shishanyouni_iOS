// 日程的唯一持久化入口，保留已有 Widget 同步行为。

import Foundation

// MARK: - 数据持久化
//Event 保存和读取日程的仓库
class EventStore {
    private let userDefaultsKey = "saved_events"
    private let completionKey = "event_completions"

    static let shared = EventStore()

    private init() {}

    func saveEvents(_ events: [Event]) {
        do {
            let data = try JSONEncoder().encode(events)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            // Widget 不直接读取 App 的 Event，保存成功后同步一份展示专用 WidgetScheduleItem 列表。
            PersonalScheduleWidgetSync.sync()
            NotificationCenter.default.post(name: .homeNextEventsDidChange, object: nil)
        } catch {
            print("❌ 日程保存失败: \(error)")
        }
    }

    func loadEvents() -> [Event] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return []
        }
        do {
            return try JSONDecoder().decode([Event].self, from: data)
        } catch {
            print("❌ 日程加载失败: \(error)")
            return []
        }
    }

    // MARK: - 完成状态管理
    func completionKey(for eventId: UUID, date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return "\(eventId.uuidString)_\(dateFormatter.string(from: date))"
    }

    func setCompletion(eventId: UUID, date: Date, completed: Bool) {
        var completions = UserDefaults.standard.dictionary(forKey: completionKey) as? [String: Bool] ?? [:]
        completions[completionKey(for: eventId, date: date)] = completed
        UserDefaults.standard.set(completions, forKey: completionKey)
        PersonalScheduleWidgetSync.sync()
        NotificationCenter.default.post(name: .homeNextEventsDidChange, object: nil)
    }

    func isCompleted(eventId: UUID, date: Date) -> Bool {
        let completions = UserDefaults.standard.dictionary(forKey: completionKey) as? [String: Bool] ?? [:]
        return completions[completionKey(for: eventId, date: date)] ?? false
    }

    func removeCompletions(for eventId: UUID) {
        var completions = UserDefaults.standard.dictionary(forKey: completionKey) as? [String: Bool] ?? [:]
        let keysToRemove = completions.keys.filter { $0.hasPrefix(eventId.uuidString) }
        for key in keysToRemove {
            completions.removeValue(forKey: key)
        }
        UserDefaults.standard.set(completions, forKey: completionKey)
        PersonalScheduleWidgetSync.sync()
        NotificationCenter.default.post(name: .homeNextEventsDidChange, object: nil)
    }

    func getAllCompletions() -> [String: Bool] {
        UserDefaults.standard.dictionary(forKey: completionKey) as? [String: Bool] ?? [:]
    }
}
