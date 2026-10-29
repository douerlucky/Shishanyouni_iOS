import Foundation

struct AddCourseContext: Identifiable
{
    let id = UUID()
    let day: Int
    let period: Int
}

// MARK: - 时间轴

struct ClassPeriod: Identifiable
{
    let id: Int
    let periodNumber: Int
    let title: String
    let displayStartTime: String
    let startTime: String
    let endTime: String
}
