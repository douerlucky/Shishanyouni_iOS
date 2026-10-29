import Foundation

/// V3 只声明单学期查询；按学期串行合并，复用同一份教务会话，不重复登录。
struct ShishanyouniGradeService
{
    let api: GradeAPI

    init(api: GradeAPI = GradeAPI()) { self.api = api }

    static func queryPlan(username: String, year: String, term: String, date: Date = Date()) throws -> [(year: String, term: String)]
    {
        guard ["0", "1", "2"].contains(term) else { throw ShishanyouniV3Error.invalidParameters }
        let current = AcademicQuerySemester.forDate(date)
        let currentYear = Int(current.year) ?? Calendar.current.component(.year, from: date)
        let years: [Int]
        if year.isEmpty
        {
            let enrollment = Int(username.prefix(4))
            let first = enrollment.flatMap { (1990 ... currentYear).contains($0) ? $0 : nil } ?? currentYear - 4
            years = Array(first ... currentYear)
        }
        else
        {
            guard let selected = Int(year), (1990 ... currentYear + 1).contains(selected) else
            {
                throw ShishanyouniV3Error.invalidParameters
            }
            years = [selected]
        }
        let allTerms = term == "0"
        return years.flatMap
        { academicYear in
            let terms = allTerms ? ["1", "2"] : [term]
            return terms.compactMap
            { semesterTerm -> (year: String, term: String)? in
                // 汇总只取已经开始的学期，避免将未来学期的“未开放”误当成整体查询失败。
                if allTerms, academicYear == currentYear, current.term == "1", semesterTerm == "2" { return nil }
                return (year: String(academicYear), term: semesterTerm)
            }
        }
    }

    func fetchGrades(
        username: String, encryptedPassword: String, year: String, term: String,
        mfa: ShishanyouniV3MFAProvider?
    ) async throws -> [Grade]
    {
        var result: [Grade] = []
        var seen = Set<String>()
        for semester in try Self.queryPlan(username: username, year: year, term: term)
        {
            try Task.checkCancellation()
            let grades = try await api.fetchSemesterGrades(
                username: username, encryptedPassword: encryptedPassword,
                xnm: semester.year, xqm: semester.term, mfa: mfa
            )
            for grade in grades
            {
                let key = "\(grade.jxb_id)|\(grade.xnm ?? semester.year)|\(grade.xqm ?? semester.term)"
                if seen.insert(key).inserted { result.append(grade) }
            }
        }
        return result
    }

}
