import Foundation

/// 将狮山有你课表响应转换为本地课程，不参与学校直连导入。
enum ShishanyouniCurriculumImporter
{
    static func fetchCourses(
        username: String,
        encryptedPassword: String,
        year: String,
        term: String,
        mfa: ShishanyouniV3MFAProvider? = nil
    ) async throws -> (courses: [Course], startDate: Date?)
    {
        let payload = try await ShishanyouniCurriculumAPI.fetchTimetable(
            username: username, encryptedPassword: encryptedPassword, year: year, term: term, mfa: mfa
        )

        let courses = try parseCourses(from: payload, year: year, term: term)

        let startDate: Date? = payload.startDate.flatMap { dateStr in
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            fmt.locale = Locale(identifier: "en_US_POSIX")
            return fmt.date(from: dateStr)
        }
        return (courses, startDate)
    }

    static func parseCourses(from payload: TimetableData, year: String, term: String) throws -> [Course]
    {
        var colorMap: [String: Int] = [:]
        var courses: [Course] = try payload.timetableModels.map { model in
            guard !model.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  (1 ... 7).contains(model.day), (1 ... 12).contains(model.start),
                  model.step > 0, model.step <= 13 - model.start,
                  !model.weekList.isEmpty, model.weekList.allSatisfy({ (1 ... 60).contains($0) }) else
            {
                throw CurriculumError.apiError("课程“\(model.name)”的星期、节次或周次无法识别，未覆盖原课表。")
            }
            if colorMap[model.name] == nil { colorMap[model.name] = model.colorRandom }
            var c = Course(from: model)
            c.colorRandom = colorMap[model.name]!
            return c
        }

        for summary in payload.others ?? []
        {
            let parts = summary.components(separatedBy: "/")
            let heading = (parts.first ?? "").replacingOccurrences(
                of: #"[（(]共\s*\d+\s*周[）)]"#, with: "", options: .regularExpression
            ).components(separatedBy: CharacterSet(charactersIn: "○◇"))
            let name = (heading.first ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let teacher = heading.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            let weekText = parts.dropFirst().first(where: { $0.contains("周") }) ?? ""
            let weeks = CurriculumWeekParser.parse(weekText)
            guard !name.isEmpty, !weeks.isEmpty else
            {
                throw CurriculumError.apiError("狮山有你其他课程的名称或周次无法识别，未覆盖原课表。")
            }
            let semester = "\(year)-\(term)"
            let id = ["backend", semester, "other", name, teacher, weeks.map(String.init).joined(separator: ",")]
                .map { "\($0.utf8.count):\($0)" }.joined(separator: "|")
            if colorMap[name] == nil { colorMap[name] = name.utf8.reduce(0) { ($0 * 31 + Int($1)) % 32 } }
            courses.append(Course(
                id: id, name: name, day: 0, start: 0, step: 0, room: nil,
                teacher: teacher.isEmpty ? nil : teacher, weekList: weeks, weeks: weekText, term: semester,
                colorRandom: colorMap[name]!, customColorHex: nil, isManual: false, courseType: .other
            ))
        }
        var seen = Set<String>()
        return courses.filter { seen.insert($0.id).inserted }
    }
}
