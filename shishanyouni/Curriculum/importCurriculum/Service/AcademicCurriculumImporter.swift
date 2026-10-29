import Foundation

/// 直接读取教务整学期课表；认证由调用方复用 SchoolAcademicAPI 完成。
enum AcademicCurriculumImporter
{
    /// 教务接口不提供开学日期，暂固定为 2026-08-31；不向狮山有你查询补全。
    static let defaultSemesterStartDate: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar.date(from: DateComponents(year: 2026, month: 8, day: 31))!
    }()

    static func academicTermCode(from appTerm: String) -> String
    {
        appTerm == "2" ? "12" : "3"
    }

    static func fetchCourses(
        cookie: String, year: String, term: String, session: URLSession = .shared
    ) async throws -> (courses: [Course], startDate: Date?)
    {
        let data = try await AcademicCurriculumAPI.fetchTimetable(
            cookie: cookie, year: year, academicTerm: academicTermCode(from: term), session: session
        )
        return (try parseCourses(from: data, year: year, term: term), defaultSemesterStartDate)
    }

    static func parseCourses(from data: Data, year: String, term: String) throws -> [Course]
    {
        let response = try JSONDecoder().decode(AcademicCurriculumResponse.self, from: data)
        guard response.kbList != nil || response.sjkList != nil else
        {
            throw CurriculumError.apiError("\(SchoolServiceName.academicPlatform)未返回课表，请重新登录后重试。")
        }

        let semester = "\(year)-\(academicTermCode(from: term))"
        var courses: [Course] = []
        for item in response.kbList ?? []
        {
            let name = item.kcmc.trimmingCharacters(in: .whitespacesAndNewlines)
            let weeks = CurriculumWeekParser.parse(item.zcd)
            guard !name.isEmpty, let day = Int(item.xqj), (1 ... 7).contains(day),
                  let periods = parsePeriods(item.jcs ?? item.jcor ?? item.jc ?? ""), !weeks.isEmpty
            else
            {
                throw CurriculumError.apiError("课程“\(name)”的星期、节次或周次无法识别，未覆盖原课表。")
            }
            courses.append(Course(
                id: stableID(["academic", semester, "regular", item.jxb_id ?? item.kch_id ?? name,
                              name, String(day), String(periods.lowerBound), String(periods.upperBound),
                              weeks.map(String.init).joined(separator: ","), item.cdmc ?? "", item.xm ?? ""]),
                name: name, day: day, start: periods.lowerBound,
                step: periods.upperBound - periods.lowerBound + 1,
                room: nonempty(item.cdmc), teacher: nonempty(item.xm),
                weekList: weeks, weeks: item.zcd, term: semester,
                colorRandom: colorIndex(for: name), customColorHex: nil, isManual: false,
                assessmentMethod: nonempty(item.khfsmc), courseType: .regular
            ))
        }

        for item in response.sjkList ?? []
        {
            let summary = nonempty(item.sjkcgs) ?? nonempty(item.qtkcgs) ?? ""
            let parts = summary.components(separatedBy: "/")
            let heading = (parts.first ?? "").replacingOccurrences(
                of: #"[（(]共\s*\d+\s*周[）)]"#, with: "", options: .regularExpression
            ).components(separatedBy: "◇")
            let name = nonempty(item.kcmc) ?? nonempty(heading.first) ?? ""
            let teacher = nonempty(item.xm) ?? (heading.count > 1 ? nonempty(heading[1]) : nil)
            let weekText = nonempty(item.zcd) ?? parts.dropFirst().first(where: { $0.contains("周") }) ?? ""
            let weeks = CurriculumWeekParser.parse(weekText)
            guard !name.isEmpty, !weeks.isEmpty else
            {
                throw CurriculumError.apiError("教务其他课程的名称或周次无法识别，未覆盖原课表。")
            }
            courses.append(Course(
                id: stableID(["academic", semester, "other", name, teacher ?? "", weeks.map(String.init).joined(separator: ",")]),
                name: name, day: 0, start: 0, step: 0, room: nil, teacher: teacher,
                weekList: weeks, weeks: weekText, term: semester,
                colorRandom: colorIndex(for: name), customColorHex: nil, isManual: false,
                courseType: .other
            ))
        }

        // 相同响应中重复记录不叠加；不同时间/周次/类型的同名课程仍各自保留。
        var seen = Set<String>()
        return courses.filter { seen.insert($0.id).inserted }
    }

    private static func parsePeriods(_ text: String) -> ClosedRange<Int>?
    {
        let value = text.replacingOccurrences(of: "第", with: "").replacingOccurrences(of: "节", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let bounds = value.split(separator: "-", omittingEmptySubsequences: false)
        guard (1 ... 2).contains(bounds.count), let firstText = bounds.first, let lastText = bounds.last,
              let first = Int(firstText), let last = Int(lastText),
              (1 ... 12).contains(first), (first ... 12).contains(last) else { return nil }
        return first ... last
    }

    private static func nonempty(_ text: String?) -> String?
    {
        let value = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }

    private static func stableID(_ parts: [String]) -> String
    {
        // 长度前缀避免课程名里出现分隔符时产生 ID 碰撞；不使用跨启动变化的 hashValue。
        parts.map { "\($0.utf8.count):\($0)" }.joined(separator: "|")
    }

    private static func colorIndex(for name: String) -> Int
    {
        name.utf8.reduce(0) { ($0 * 31 + Int($1)) % 32 }
    }
}
