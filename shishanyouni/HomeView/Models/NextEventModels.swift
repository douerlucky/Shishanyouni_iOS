import Foundation
import SwiftUI

extension Notification.Name
{
    /// 课程、日程或校历写入完成后发出，首页无需重新进入即可更新“下一个安排”。
    static let homeNextEventsDidChange = Notification.Name("homeNextEventsDidChange")
}

// MARK: - 统一事件模型

struct NextEventItem: Identifiable
{
    let id: String
    /// 事件标题（课程名、日程标题、考试科目）
    let title: String
    /// 地点/教室
    let subtitle: String?
    /// 额外信息（如课程教师）
    let detail: String?
    /// 事件发生时间（用于排序）
    let date: Date
    /// 事件类型
    let type: NextEventType
}

enum NextEventType: String
{
    case course = "课程"
    case userEvent = "日程"
    case schoolCalendar = "校历"
    case exam = "考试"

    var icon: String
    {
        switch self
        {
        case .course: return "book.fill"
        case .userEvent: return "checklist"
        case .schoolCalendar: return "calendar"
        case .exam: return "pencil.and.list.clipboard"
        }
    }

    var color: Color
    {
        switch self
        {
        case .course: return .blue
        case .userEvent: return .orange
        case .schoolCalendar: return .green
        case .exam: return .red
        }
    }
}
