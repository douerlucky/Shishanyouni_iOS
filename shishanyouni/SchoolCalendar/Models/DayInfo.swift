import Foundation

struct DayInfo: Identifiable {
    let id = UUID()
    let date: Date
    let day: Int
    let isCurrentMonth: Bool
    let isToday: Bool

    var schoolEventCount: Int = 0
    var personalEventCount: Int = 0
    var hasSchoolEvent: Bool { schoolEventCount > 0 }
    var hasPersonalEvent: Bool { personalEventCount > 0 }
}
