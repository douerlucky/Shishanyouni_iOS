//
//  Event.swift
//  shishanyouni
//  日程服务（数据结构已迁移至 Data/UserData.swift）

import Foundation
import SwiftUI

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

        guard let rule = repeatRule else {
            if dateRange.contains(date) { return [self] }
            return []
        }

        let startDate = dateRange.lowerBound
        let endDate = dateRange.upperBound

        var currentDate = date
        var instanceCount = 0

        while currentDate <= endDate {
            if currentDate >= startDate {
                var instance = self
                instance.date = currentDate
                instance.isCompleted = EventStore.shared.isCompleted(eventId: id, date: currentDate)
                instances.append(instance)
            }

            guard let nextDate = nextOccurrence(from: currentDate, rule: rule) else { break }

            switch rule.endCondition {
            case .never: break
            case .untilDate(let until): if nextDate > until { return instances }
            case .count(let count): instanceCount += 1; if instanceCount >= count { return instances }
            }

            currentDate = nextDate
        }

        return instances
    }

    private func nextOccurrence(from date: Date, rule: RepeatRule) -> Date? {
        let calendar = Calendar.current
        switch rule.frequency {
        case .daily: return calendar.date(byAdding: .day, value: rule.interval, to: date)
        case .weekly: return calendar.date(byAdding: .day, value: 7 * rule.interval, to: date)
        case .biweekly: return calendar.date(byAdding: .day, value: 14 * rule.interval, to: date)
        case .monthly: return calendar.date(byAdding: .month, value: rule.interval, to: date)
        case .custom: return calendar.date(byAdding: .day, value: rule.interval, to: date)
        }
    }
}
