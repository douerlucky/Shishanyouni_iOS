import Foundation
import SwiftUI

// 日程、重复规则及日程颜色。


// MARK: - 事项分类
enum EventCategory: String, Codable, CaseIterable, Equatable {
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
enum RepeatFrequency: String, Codable, CaseIterable, Equatable {
    case daily = "每天"
    case weekly = "每周"
    case biweekly = "隔周"
    case monthly = "每月"
    case custom = "自定义间隔"
}

enum RepeatEndCondition: Codable, Equatable {
    case never
    case untilDate(Date)
    case count(Int)
}

struct RepeatRule: Codable, Equatable {
    let frequency: RepeatFrequency
    let interval: Int  // 间隔，例如 2 表示每2天/周
    let endCondition: RepeatEndCondition

    init(frequency: RepeatFrequency, interval: Int = 1, endCondition: RepeatEndCondition = .never) {
        self.frequency = frequency
        self.interval = interval
        self.endCondition = endCondition
    }
}

//用户自己创建的一条日程
struct Event: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String //标题
    var date: Date //日期
    var isAllDay: Bool
    var startTime: Date? //开始时间
    var endTime: Date? //结束时间
    var note: String?
    var location: String? //地点
    var category: EventCategory //分类
    var colorIndex: Int?
    var isCompleted: Bool
    var repeatRule: RepeatRule?

    init(id: UUID = UUID(), title: String, date: Date, isAllDay: Bool = false, startTime: Date? = nil, endTime: Date? = nil, note: String? = nil, location: String? = nil, category: EventCategory = .todo, colorIndex: Int? = nil, isCompleted: Bool = false, repeatRule: RepeatRule? = nil) {
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
    }

    var isOverdue: Bool {
        false
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
    }

    var displayColor: Color {
        if let idx = colorIndex {
            return EventColorPalette.color(for: idx)
        }
        return category.defaultColor
    }
}
