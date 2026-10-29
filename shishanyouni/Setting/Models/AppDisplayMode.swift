import Foundation

/// App 的整体展示模式。
///
/// “全部”和“无通行证内容”是锁定预设；只有“自定义”允许逐项调整。
enum AppDisplayMode: String, CaseIterable, Identifiable
{
    case all = "all"
    case noCampusPassContent = "noCampusPassContent"
    case custom = "custom"

    var id: String { rawValue }

    var title: String
    {
        switch self
        {
        case .all: return "全部"
        case .noCampusPassContent: return "无通行证内容"
        case .custom: return "自定义"
        }
    }

    var description: String
    {
        switch self
        {
        case .all: return "显示全部页面、首页内容和通行证功能。"
        case .noCampusPassContent: return "关闭日程，保留首页全部内容，并隐藏通行证功能。"
        case .custom: return "按你的偏好调整每项内容。"
        }
    }

    /// 兼容 1.4.x 曾经使用过的存储值，避免升级后模式丢失。
    static func fromStoredValue(_ rawValue: String) -> Self
    {
        switch rawValue
        {
        case "simple": return .noCampusPassContent
        case "complete": return .all
        default: return Self(rawValue: rawValue) ?? .all
        }
    }

}
