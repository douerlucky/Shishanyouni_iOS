//
//  SchoolCalendarData.swift
//  shishanyouni
//

import Foundation

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

struct SchoolCalendarEvent: Identifiable, Codable {
    let id: UUID
    var title: String
    var startDate: Date
    var endDate: Date?
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

struct SchoolCalendarStore {
    private let userDefaultsKey = "school_calendar_events"
    
    static let shared = SchoolCalendarStore()
    
    private init() {}
    
    func saveEvents(_ events: [SchoolCalendarEvent]) {
        do {
            let data = try JSONEncoder().encode(events)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("❌ 校历保存失败: \(error)")
        }
    }
    
    func loadEvents() -> [SchoolCalendarEvent] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return buildDefaults()
        }
        do {
            let loaded = try JSONDecoder().decode([SchoolCalendarEvent].self, from: data)
            return loaded.isEmpty ? buildDefaults() : loaded
        } catch {
            print("❌ 校历加载失败: \(error)")
            return buildDefaults()
        }
    }
    
    func semesterStartDate() -> Date {
        let ts = UserDefaults.standard.double(forKey: "semesterStartDateTimestamp")
        if ts > 0 {
            return Date(timeIntervalSince1970: ts)
        }
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 2
        return Calendar.current.date(from: components) ?? Date()
    }
    
    private func lunarHolidayDate(year: Int, holiday: String) -> (month: Int, day: Int)? {
        // 农历节日公历对照表（每年不同）
        let table: [String: [Int: (Int, Int)]] = [
            "dragon": [  // 端午节（农历五月初五）
                2025: (5, 31),
                2026: (6, 19),
                2027: (6, 9),
                2028: (5, 28),
            ],
            "midautumn": [  // 中秋节（农历八月十五）
                2025: (10, 6),
                2026: (9, 25),
                2027: (9, 24),
                2028: (10, 3),
            ],
        ]
        return table[holiday]?[year]
    }
    
    private func buildDefaults() -> [SchoolCalendarEvent] {
        let cal = Calendar.current
        
        var events: [SchoolCalendarEvent] = []
        let semesterStart = semesterStartDate()
        let semYear = cal.component(.year, from: semesterStart)
        let semMonth = cal.component(.month, from: semesterStart)
        
        let isSpring = semMonth <= 6
        
        if isSpring {
            // 春季学期 (2-7月)
            events.append(SchoolCalendarEvent(
                title: "春季学期开学",
                startDate: semesterStart,
                type: .trimesterStart,
                description: "正式上课"
            ))
            
            // 清明节（公历4月4-5日左右，属节气非农历，日期基本固定）
            if let qingming = date(year: semYear, month: 4, day: 4, calendar: cal) {
                events.append(SchoolCalendarEvent(
                    title: "清明节假期",
                    startDate: qingming,
                    endDate: cal.date(byAdding: .day, value: 2, to: qingming),
                    type: .holiday
                ))
            }
            
            if let labor = date(year: semYear, month: 5, day: 1, calendar: cal) {
                events.append(SchoolCalendarEvent(
                    title: "劳动节假期",
                    startDate: labor,
                    endDate: cal.date(byAdding: .day, value: 4, to: labor),
                    type: .holiday
                ))
            }
            
            // 端午节（农历五月初五，公历日期每年查表）
            if let dragonDate = lunarHolidayDate(year: semYear, holiday: "dragon"),
               let dragon = date(year: semYear, month: dragonDate.month, day: dragonDate.day, calendar: cal) {
                events.append(SchoolCalendarEvent(
                    title: "端午节假期",
                    startDate: dragon,
                    endDate: cal.date(byAdding: .day, value: 2, to: dragon),
                    type: .holiday
                ))
            }
            
            let examStart = cal.date(byAdding: .weekOfYear, value: 18, to: semesterStart) ?? semesterStart
            events.append(SchoolCalendarEvent(
                title: "期末考试周",
                startDate: examStart,
                endDate: cal.date(byAdding: .day, value: 6, to: examStart),
                type: .exam
            ))
            
            let semEnd = cal.date(byAdding: .weekOfYear, value: 19, to: semesterStart) ?? semesterStart
            let vacationStart = cal.date(byAdding: .day, value: 1, to: semEnd)
            events.append(SchoolCalendarEvent(
                title: "暑假开始",
                startDate: vacationStart ?? semEnd,
                type: .trimesterEnd,
                description: "正式放暑假"
            ))
        } else {
            // 秋季学期 (9-1月)
            if let fallStart = date(year: semYear, month: 9, day: 1, calendar: cal) {
                events.append(SchoolCalendarEvent(
                    title: "秋季学期开学",
                    startDate: fallStart,
                    type: .trimesterStart,
                    description: "正式上课"
                ))
                
                // 中秋节（农历八月十五，公历日期每年查表）
                if let midDate = lunarHolidayDate(year: semYear, holiday: "midautumn"),
                   let midautumn = date(year: semYear, month: midDate.month, day: midDate.day, calendar: cal) {
                    events.append(SchoolCalendarEvent(
                        title: "中秋节假期",
                        startDate: midautumn,
                        endDate: cal.date(byAdding: .day, value: 2, to: midautumn),
                        type: .holiday
                    ))
                }
                
                if let national = date(year: semYear, month: 10, day: 1, calendar: cal) {
                    events.append(SchoolCalendarEvent(
                        title: "国庆节假期",
                        startDate: national,
                        endDate: cal.date(byAdding: .day, value: 6, to: national),
                        type: .holiday
                    ))
                }
                
                if let newYear = date(year: semYear + 1, month: 1, day: 1, calendar: cal) {
                    events.append(SchoolCalendarEvent(
                        title: "元旦假期",
                        startDate: newYear,
                        endDate: newYear,
                        type: .holiday
                    ))
                }
                
                let examStart = cal.date(byAdding: .weekOfYear, value: 18, to: fallStart) ?? fallStart
                events.append(SchoolCalendarEvent(
                    title: "期末考试周",
                    startDate: examStart,
                    endDate: cal.date(byAdding: .day, value: 6, to: examStart),
                    type: .exam
                ))
                
                let semEnd = cal.date(byAdding: .weekOfYear, value: 19, to: fallStart) ?? fallStart
                let vacationStart = cal.date(byAdding: .day, value: 1, to: semEnd)
                events.append(SchoolCalendarEvent(
                    title: "寒假开始",
                    startDate: vacationStart ?? semEnd,
                    type: .trimesterEnd,
                    description: "正式放寒假"
                ))
            }
        }
        
        return events
    }
    
    private func date(year: Int, month: Int, day: Int, calendar: Calendar) -> Date? {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        return calendar.date(from: comps)
    }
}
