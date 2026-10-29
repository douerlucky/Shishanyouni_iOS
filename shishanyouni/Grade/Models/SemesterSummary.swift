import Foundation

// MARK: - Semester Summary Data

struct SemesterSummary: Identifiable
{
    let id = UUID()
    let semester: String
    let termLabel: String
    let gpa: Double
    let avgScore: Double
    let totalCredits: Double
    let courseCount: Int
    let grades: [Grade]
}
