import Foundation

enum CourseMutationStatus
{
    case success
    case rejected
    case unknown
}

struct CourseMutationResult
{
    let status: CourseMutationStatus
    let message: String
    let verified: Bool?

    var succeeded: Bool { status == .success && verified == true }
}

/// 选课前的只读准备结果。单层课程直接进入确认；多层课程必须先让用户选择子教学班。
enum CourseSelectionPreparation
{
    case direct(CourseChildClass)
    case needsChildSelection([CourseChildClass])
}
