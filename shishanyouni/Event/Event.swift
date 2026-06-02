//
//  Event.swift
//  shishanyouni
//  Created by 寒海澜沧 on 2026/3/20

import Foundation
import SwiftUI

// MARK: - 优先级
enum EventPriority: String, Codable, CaseIterable {
    case high = "⚠️ 高"
    case medium = "中"
    case low = "低"

    var sortOrder: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }

    var systemImage: String {
        switch self {
        case .high: return "exclamationmark.3"
        case .medium: return "exclamationmark.2"
        case .low: return "exclamationmark"
        }
    }

    var tintColor: Color {
        switch self {
        case .high: return .red
        case .medium: return .orange
        case .low: return .gray
        }
    }
}

// MARK: - 事项分类
enum EventCategory: String, Codable, CaseIterable {
    case trip = "行程"
    case todo = "待办"
    case memo = "备忘"
    
    var systemImage: String {
        switch self {
        case .trip: return "mappin.and.ellipse"
        case .todo: return "checklist"
        case .memo: return "note.text"
        }
    }
    
    var defaultColor: Color {
        switch self {
        case .trip: return Color.adaptive(light: Color(red: 0.20, green: 0.49, blue: 0.92), dark: Color(red: 0.38, green: 0.62, blue: 0.95))
        case .todo: return Color.adaptive(light: Color(red: 0.95, green: 0.47, blue: 0.18), dark: Color(red: 0.98, green: 0.60, blue: 0.35))
        case .memo: return Color.adaptive(light: Color(red: 0.50, green: 0.34, blue: 0.86), dark: Color(red: 0.60, green: 0.48, blue: 0.92))
        }
    }
}

// MARK: - 自定义颜色选项
struct EventColorPalette {
    static let colors: [Color] = [
        Color.adaptive(light: Color(red: 0.20, green: 0.49, blue: 0.92), dark: Color(red: 0.38, green: 0.62, blue: 0.95)),
        Color.adaptive(light: Color(red: 0.95, green: 0.47, blue: 0.18), dark: Color(red: 0.98, green: 0.60, blue: 0.35)),
        Color.adaptive(light: Color(red: 0.50, green: 0.34, blue: 0.86), dark: Color(red: 0.60, green: 0.48, blue: 0.92)),
        Color.adaptive(light: Color(red: 0.26, green: 0.69, blue: 0.31), dark: Color(red: 0.35, green: 0.75, blue: 0.40)),
        Color.adaptive(light: Color(red: 0.89, green: 0.24, blue: 0.22), dark: Color(red: 0.95, green: 0.40, blue: 0.38)),
        Color.adaptive(light: Color(red: 0.12, green: 0.70, blue: 0.74), dark: Color(red: 0.28, green: 0.78, blue: 0.80)),
        Color.adaptive(light: Color(red: 0.90, green: 0.58, blue: 0.16), dark: Color(red: 0.94, green: 0.68, blue: 0.32)),
        Color.adaptive(light: Color(red: 0.69, green: 0.34, blue: 0.78), dark: Color(red: 0.78, green: 0.48, blue: 0.85)),
        Color.adaptive(light: Color(red: 0.70, green: 0.55, blue: 0.40), dark: Color(red: 0.80, green: 0.65, blue: 0.50)),
        Color.adaptive(light: Color(red: 0.45, green: 0.45, blue: 0.55), dark: Color(red: 0.60, green: 0.60, blue: 0.70)),
    ]
    
    static func color(for index: Int) -> Color {
        colors[index % colors.count]
    }
    
    static func hexString(for color: Color) -> String? {
        #if canImport(UIKit)
        let uiColor = UIColor(color)
        guard let components = uiColor.cgColor.components, components.count >= 3 else { return nil }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
        #else
        return nil
        #endif
    }
}

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

// MARK: - 子任务
struct SubTask: Identifiable, Codable {
    let id: UUID
    var title: String
    var isCompleted: Bool

    init(id: UUID = UUID(), title: String = "", isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
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
    var location: String?
    var category: EventCategory
    var colorIndex: Int?
    var isCompleted: Bool
    var repeatRule: RepeatRule?
    var priority: EventPriority
    var dueDate: Date?
    var subtasks: [SubTask]

    var subtaskProgress: (done: Int, total: Int) {
        guard !subtasks.isEmpty else { return (0, 0) }
        let done = subtasks.filter(\.isCompleted).count
        return (done, subtasks.count)
    }

    init(id: UUID = UUID(), title: String, date: Date, isAllDay: Bool = false, startTime: Date? = nil, endTime: Date? = nil, note: String? = nil, location: String? = nil, category: EventCategory = .todo, colorIndex: Int? = nil, isCompleted: Bool = false, repeatRule: RepeatRule? = nil, priority: EventPriority = .medium, dueDate: Date? = nil, subtasks: [SubTask] = []) {
        self.id = id
        self.title = title
        self.date = date
        self.isAllDay = isAllDay
        self.startTime = startTime
        self.endTime = endTime
        self.note = note
        self.location = location
        self.category = category
        self.colorIndex = colorIndex
        self.isCompleted = isCompleted
        self.repeatRule = repeatRule
        self.priority = priority
        self.dueDate = dueDate
        self.subtasks = subtasks
    }

    var isOverdue: Bool {
        guard !isCompleted, let due = dueDate else { return false }
        return Calendar.current.startOfDay(for: Date()) > Calendar.current.startOfDay(for: due)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        date = try container.decode(Date.self, forKey: .date)
        isAllDay = try container.decode(Bool.self, forKey: .isAllDay)
        startTime = try container.decodeIfPresent(Date.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        category = try container.decodeIfPresent(EventCategory.self, forKey: .category) ?? .todo
        colorIndex = try container.decodeIfPresent(Int.self, forKey: .colorIndex)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        repeatRule = try container.decodeIfPresent(RepeatRule.self, forKey: .repeatRule)
        priority = try container.decodeIfPresent(EventPriority.self, forKey: .priority) ?? .medium
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        subtasks = try container.decodeIfPresent([SubTask].self, forKey: .subtasks) ?? []
    }

    var displayColor: Color {
        if let idx = colorIndex {
            return EventColorPalette.color(for: idx)
        }
        return category.defaultColor
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
