import Foundation

enum EventEditMode {
    case add
    case edit(Event)

    var title: String {
        switch self {
        case .add: return "添加日程"
        case .edit: return "编辑日程"
        }
    }

    var buttonTitle: String {
        switch self {
        case .add: return "添加"
        case .edit: return "保存"
        }
    }
}
