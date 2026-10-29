import Foundation

/// 新建课程或编辑一组已合并展示的课程。
enum CourseGroupEditorMode
{
    case add(prefillWeekday: Int = 1, prefillPeriod: Int = 1)
    case edit(CourseGroup)

    var title: String
    {
        switch self
        {
        case .add: return "手动添加课程"
        case .edit: return "编辑课程"
        }
    }

    var buttonTitle: String
    {
        switch self
        {
        case .add: return "添加"
        case .edit: return "保存"
        }
    }
}
