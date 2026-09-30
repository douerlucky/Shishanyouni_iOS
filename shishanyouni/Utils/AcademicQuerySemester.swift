import Foundation

/// 成绩、考试查询共用的当前学期。学年以 9 月开始：9 月至次年 1 月为第一学期，2 月至 8 月为第二学期。
struct AcademicQuerySemester
{
    let year: String
    let term: String

    static func forDate(_ date: Date, calendar: Calendar = .current) -> Self
    {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)

        // 8 月 31 日仍属于第二学期，9 月 1 日才切换到下一学年。
        return Self(
            year: String(month >= 9 ? year : year - 1),
            term: (month >= 9 || month == 1) ? "1" : "2"
        )
    }
}
