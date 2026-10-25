import SwiftUI

/// 需要读取校园账号信息的功能范围。
///
/// 授权按功能、按账号分别记录，避免用户同意一个功能后，其他功能也被
/// 静默放行；切换账号后也会自然回到未授权状态。
enum FeatureAuthorizationScope: String, CaseIterable, Identifiable
{
    case grades
    case exams
    case nanhuRun
    case chooseCourse
    case itc
    case allCourses
    case physicalTest
    case electricity
    case libraryReservation

    var id: String { rawValue }

    var displayName: String
    {
        switch self
        {
        case .grades: return "成绩查询"
        case .exams: return "考试查询"
        case .nanhuRun: return "环湖跑查询"
        case .chooseCourse: return "选课"
        case .itc: return "ITC平台"
        case .allCourses: return "全校课程查询"
        case .physicalTest: return "体测查询"
        case .electricity: return "电费查询"
        case .libraryReservation: return "图书馆预约"
        }
    }

    var systemImage: String
    {
        switch self
        {
        case .grades: return "graduationcap.fill"
        case .exams: return "pencil.line"
        case .nanhuRun: return "figure.run"
        case .chooseCourse: return "checklist"
        case .itc: return "chevron.left.forwardslash.chevron.right"
        case .allCourses: return "mail.and.text.magnifyingglass"
        case .physicalTest: return "figure.run.square.stack.fill"
        case .electricity: return "gauge.with.needle.fill"
        case .libraryReservation: return "building.columns.fill"
        }
    }

    var tint: Color
    {
        switch self
        {
        case .grades: return .red
        case .exams: return .orange
        case .nanhuRun: return .teal
        case .chooseCourse: return .yellow
        case .itc: return .green
        case .allCourses: return .indigo
        case .physicalTest: return .blue
        case .electricity: return .purple
        case .libraryReservation: return .cyan
        }
    }

    /// 授权页必须明确说明账号信息会被送到哪里查询。
    var sourceDescription: String
    {
        switch self
        {
        case .grades:
            return "默认通过“狮山有你”接口查询；进入后可切换为直接访问“\(SchoolServiceName.teachingSystem)”。"
        case .allCourses:
            return "默认通过“狮山有你”接口查询；进入后可切换为直接访问“\(SchoolServiceName.academicPlatform)”。"
        case .exams:
            return "默认直接访问“\(SchoolServiceName.academicPlatform)”查询；进入后可切换为“狮山有你”接口。"
        case .nanhuRun:
            return "默认直接访问“\(SchoolServiceName.sportsCloud)”查询；进入后可切换为“狮山有你”接口。"
        case .chooseCourse, .physicalTest, .itc, .electricity, .libraryReservation:
            return "本功能会直接访问学校相关系统查询或办理，不经过狮山有你接口代查。"
        }
    }

    /// 这些功能已有校园通行证限制；授权 Sheet 必须在付费墙之后出现。
    var requiresCampusPass: Bool
    {
        switch self
        {
        case .chooseCourse, .itc, .physicalTest, .libraryReservation:
            return true
        default:
            return false
        }
    }
}
