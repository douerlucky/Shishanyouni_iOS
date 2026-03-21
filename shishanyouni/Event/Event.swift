//
//  Event.swift
//  shishanyouni
//  Created by 寒海澜沧 on 2026/3/20

import Foundation

// MARK: - 重复规则
enum RepeatFrequency: String, Codable, CaseIterable {
    case daily = "每天"
    case weekly = "每周"
    case biweekly = "隔周"
    case monthly = "每月"
    case custom = "自定义间隔"
}

enum RepeatEndCondition: Codable {
    case never
    case untilDate(Date)
    case count(Int)
}

struct RepeatRule: Codable {
    let frequency: RepeatFrequency
    let interval: Int  // 间隔，例如 2 表示每2天/周
    let endCondition: RepeatEndCondition
    
    init(frequency: RepeatFrequency, interval: Int = 1, endCondition: RepeatEndCondition = .never) {
        self.frequency = frequency
        self.interval = interval
        self.endCondition = endCondition
    }
}

struct Event: Identifiable, Codable {
    let id: UUID
    var title: String
    var date: Date
    var isAllDay: Bool
    var startTime: Date?
    var endTime: Date?
    var note: String?
    var isCompleted: Bool
    var repeatRule: RepeatRule?
    
    init(id: UUID = UUID(), title: String, date: Date, isAllDay: Bool = false, startTime: Date? = nil, endTime: Date? = nil, note: String? = nil, isCompleted: Bool = false, repeatRule: RepeatRule? = nil) {
        self.id = id
        self.title = title
        self.date = date
        self.isAllDay = isAllDay
        self.startTime = startTime
        self.endTime = endTime
        self.note = note
        self.isCompleted = isCompleted
        self.repeatRule = repeatRule
    }
}

// MARK: - 数据持久化
class EventStore {
    private let userDefaultsKey = "saved_events"
    private let completionKey = "event_completions"
    
    static let shared = EventStore()
    
    private init() {}
    
    func saveEvents(_ events: [Event]) {
        do {
            let data = try JSONEncoder().encode(events)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
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
    }
    
    func getAllCompletions() -> [String: Bool] {
        UserDefaults.standard.dictionary(forKey: completionKey) as? [String: Bool] ?? [:]
    }
}

// MARK: - 日期格式化辅助
extension Event {
    func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年MM月dd日"
        return formatter.string(from: date)
    }
    
    func formattedTime() -> String? {
        guard let start = startTime else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        if let end = endTime {
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        } else {
            return formatter.string(from: start)
        }
    }
    
    // MARK: - 重复实例生成
    func instances(in dateRange: ClosedRange<Date>) -> [Event] {
        var instances: [Event] = []
        let calendar = Calendar.current
        
        // 非重复事件
        guard let rule = repeatRule else {
            if dateRange.contains(date) {
                return [self]
            }
            return []
        }
        
        // 计算重复日期序列
        let startDate = dateRange.lowerBound
        let endDate = dateRange.upperBound
        
        var currentDate = date
        var instanceCount = 0
        
        while currentDate <= endDate {
            if currentDate >= startDate {
                // 创建实例
                var instance = self
                instance.date = currentDate
                instance.isCompleted = EventStore.shared.isCompleted(eventId: id, date: currentDate)
                instances.append(instance)
            }
            
            // 计算下一个日期
            guard let nextDate = nextOccurrence(from: currentDate, rule: rule) else {
                break
            }
            
            // 检查结束条件
            switch rule.endCondition {
            case .never:
                break
            case .untilDate(let until):
                if nextDate > until {
                    return instances
                }
            case .count(let count):
                instanceCount += 1
                if instanceCount >= count {
                    return instances
                }
            }
            
            currentDate = nextDate
        }
        
        return instances
    }
    
    private func nextOccurrence(from date: Date, rule: RepeatRule) -> Date? {
        let calendar = Calendar.current
        switch rule.frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: rule.interval, to: date)
        case .weekly:
            return calendar.date(byAdding: .day, value: 7 * rule.interval, to: date)
        case .biweekly:
            return calendar.date(byAdding: .day, value: 14 * rule.interval, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: rule.interval, to: date)
        case .custom:
            // 自定义间隔按天处理
            return calendar.date(byAdding: .day, value: rule.interval, to: date)
        }
    }
}
