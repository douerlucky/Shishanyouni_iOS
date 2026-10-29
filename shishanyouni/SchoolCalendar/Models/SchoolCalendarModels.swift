import Foundation

// 校历事件与类型。


enum SchoolEventType: String, Codable, CaseIterable {
    case holiday = "假期"
    case exam = "考试"
    case trimesterStart = "学期开始"
    case trimesterEnd = "学期结束"
    case activity = "活动"
    case other = "其他"

    var systemImage: String {
        switch self {
        case .holiday: return "sun.max.fill"
        case .exam: return "pencil.and.list.clipboard"
        case .trimesterStart: return "flag.fill"
        case .trimesterEnd: return "flag.checkered"
        case .activity: return "star.fill"
        case .other: return "info.circle.fill"
        }
    }
}

// 校历事件
struct SchoolCalendarEvent: Identifiable, Codable {
    let id: UUID
    var title: String //事件名
    var startDate: Date //开始日期
    var endDate: Date? //结束日期
    var type: SchoolEventType
    var description: String?

    init(id: UUID = UUID(), title: String, startDate: Date, endDate: Date? = nil, type: SchoolEventType = .other, description: String? = nil) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.type = type
        self.description = description
    }

    func contains(date: Date) -> Bool {
        let cal = Calendar.current
        let target = cal.startOfDay(for: date)
        let start = cal.startOfDay(for: startDate)
        if let end = endDate {
            let endDay = cal.startOfDay(for: end)
            return target >= start && target <= endDay
        }
        return target == start
    }

    func formattedDateRange() -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        if let end = endDate {
            if startDate == end {
                fmt.dateFormat = "M月d日"
                return fmt.string(from: startDate)
            }
            fmt.dateFormat = "M月d日"
            let endFmt = DateFormatter()
            endFmt.locale = Locale(identifier: "zh_CN")
            endFmt.dateFormat = "M月d日"
            return "\(fmt.string(from: startDate)) - \(endFmt.string(from: end))"
        }
        fmt.dateFormat = "M月d日"
        return fmt.string(from: startDate)
    }
}
