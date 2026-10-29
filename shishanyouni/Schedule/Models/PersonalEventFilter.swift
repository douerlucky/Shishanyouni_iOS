import Foundation

// MARK: - 行程筛选

enum PersonalEventFilter: String, CaseIterable
{
    case today = "今天"
    case thisWeek = "本周"
    case all = "全部"
    case todo = "待办"
    case incomplete = "未完成"

    var systemImage: String
    {
        switch self
        {
        case .today: return "sun.max"
        case .thisWeek: return "calendar.badge.clock"
        case .all: return "list.bullet"
        case .todo: return "checklist"
        case .incomplete: return "circle"
        }
    }
}
