import Foundation

// MARK: - 学期成绩汇总

struct AISemesterGradeData
{
    let semesterLabel: String
    let gpa: Double
    let totalCredits: Double
    let grades: [Grade]
}
