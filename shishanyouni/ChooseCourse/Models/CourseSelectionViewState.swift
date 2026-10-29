import Foundation

struct PendingSelection
{
    let course: CourseSearchResult
    let childClass: CourseChildClass
    let cookie: String
    let semester: SelectedCourseSemester
    let session: CourseSelectionSession
}

struct PendingParentSelection
{
    let course: CourseSearchResult
    let cookie: String
    let semester: SelectedCourseSemester
    let session: CourseSelectionSession
}

struct ParentSelectionState: Identifiable
{
    let id = UUID()
    let course: CourseSearchResult
    let parentClasses: [CourseSearchResult]
    let cookie: String
    let semester: SelectedCourseSemester
    let session: CourseSelectionSession
}

struct ChildSelectionState: Identifiable
{
    let id = UUID()
    let course: CourseSearchResult
    let childClasses: [CourseChildClass]
    let cookie: String
    let semester: SelectedCourseSemester
    let session: CourseSelectionSession
}

/// 只在内存中存在的“账号 + 目录版本”标识。它不包含 Cookie 或任何个人字段，
/// 仅用于丢弃过期异步结果，防止切换账号后旧教学班数据回写到新页面。
struct CourseSelectionSession: Equatable
{
    let accountIdentifier: String
    let catalogRequestID: UUID
}

struct CourseActionConfirmation: Identifiable
{
    enum Action
    {
        case drop(SelectedCourse)
    }

    let id = UUID()
    let action: Action

    static func drop(_ course: SelectedCourse) -> CourseActionConfirmation
    {
        CourseActionConfirmation(action: .drop(course))
    }
}

struct CourseActionFeedback: Identifiable
{
    enum Kind
    {
        case success
        case warning
        case error
    }

    let id = UUID()
    let title: String
    let message: String
    let kind: Kind
}

/// 选课页只挂载一个 Alert；这样确认框和结果提示不会互相覆盖。
enum CourseActionAlert: Identifiable
{
    case confirmation(CourseActionConfirmation)
    case feedback(CourseActionFeedback)

    var id: UUID
    {
        switch self
        {
        case let .confirmation(value): return value.id
        case let .feedback(value): return value.id
        }
    }
}
