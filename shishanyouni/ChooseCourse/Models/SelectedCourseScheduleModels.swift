import Foundation

/// `cxZkcZzxkYzb` 返回的一条实际排课。它是只读展示数据，绝不携带或生成退选 token。
struct SelectedCourseScheduleEntry: Identifiable, Hashable
{
    let courseID: String?
    let courseCode: String?
    let courseName: String
    /// 请求中的主教学班 ID（响应的 `fjxb_id`）。实验 / 子班通过它归属到主课。
    let parentTeachingClassID: String?
    let teachingClassID: String?
    let teachingClassName: String?
    let teacher: String?
    let classTime: String
    let location: String?

    var id: String
    {
        [
            courseID,
            courseCode,
            courseName,
            parentTeachingClassID,
            teachingClassID,
            teachingClassName,
            teacher,
            classTime,
            location
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .joined(separator: "|")
    }

    var displayLocation: String?
    {
        Self.displayText(location)
    }

    var displayTeachingClassName: String?
    {
        Self.displayText(teachingClassName)
    }

    var displayTeacher: String?
    {
        guard let teacher = Self.displayText(teacher) else { return nil }
        let parts = teacher.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        return parts.count >= 2 ? Self.displayText(parts[1]) : teacher
    }

    /// `fjxb_id` 是最可靠的父子关系。只有响应缺少父 ID 时，才退回服务端明确给出的
    /// 课程 ID、课程号、教学班 ID 或完全相同的课程名称，避免把同名课程误合并。
    func belongs(to course: SelectedCourse) -> Bool
    {
        let entryParent = Self.usableIdentifier(parentTeachingClassID)
        let selectedParent = Self.normalizedIdentifier(course.parentTeachingClassID)
        if !entryParent.isEmpty, !selectedParent.isEmpty
        {
            return entryParent == selectedParent
        }

        if Self.identifiersMatch(courseID, course.courseID) { return true }
        if Self.identifiersMatch(courseCode, course.courseCode) { return true }
        if Self.identifiersMatch(teachingClassID, course.teachingClassID) { return true }

        let ownName = Self.normalizedIdentifier(courseName)
        let selectedName = Self.normalizedIdentifier(course.courseName)
        return !ownName.isEmpty && ownName == selectedName
    }

    static func decodeEntries(from data: Data) throws -> [SelectedCourseScheduleEntry]
    {
        let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        var rows: [[String: Any]] = []
        collectRows(from: object, into: &rows)

        var seen = Set<String>()
        return rows.compactMap(SelectedCourseScheduleEntry.init(dictionary:)).filter
        { entry in
            // 同一条记录在部分模板中会同时出现在顶层和嵌套列表；按稳定字段去重。
            seen.insert(entry.id).inserted
        }
    }

    /// 把已选接口提供的主教学班安排转换成同一结构，后续与实验安排统一解析。
    init?(course: SelectedCourse)
    {
        guard let classTime = course.displayClassTime else { return nil }

        self.courseID = Self.displayText(course.courseID)
        self.courseCode = course.displayCourseCode
        self.courseName = course.courseName
        self.parentTeachingClassID = Self.displayText(course.parentTeachingClassID)
        self.teachingClassID = Self.displayText(course.teachingClassID)
        self.teachingClassName = course.displayTeachingClassName
        self.teacher = course.teacherName == "暂未提供" ? nil : course.teacherName
        self.classTime = classTime
        self.location = course.displayLocation
    }

    private init?(dictionary: [String: Any])
    {
        let courseID = Self.firstString(in: dictionary, keys: ["kch_id", "course_id", "courseId", "kcid"])
        let courseCode = Self.firstString(in: dictionary, keys: ["kch", "courseCode", "kcdm"])
        let parentTeachingClassID = Self.firstString(
            in: dictionary,
            keys: ["fjxb_id", "fjxbId", "parent_jxb_id", "parentJxbId"]
        )
        let teachingClassID = Self.firstString(in: dictionary, keys: ["jxb_id", "jxbid", "jxbId", "classId"])
        let teachingClassName = Self.firstString(
            in: dictionary,
            keys: ["jxbmc", "className", "jxbmc_display", "xsmc"]
        )
        let courseName = Self.firstString(in: dictionary, keys: ["kcmc", "courseName", "name", "kcmc_display"])
            ?? teachingClassName
            ?? "课表安排"
        let teacher = Self.firstString(in: dictionary, keys: ["jsxm", "xm", "jsxx", "teacher", "teacherName"])
        let location = Self.firstString(in: dictionary, keys: ["jxdd", "cdmc", "room", "location", "jxcd"])
        let classTime = Self.firstString(in: dictionary, keys: ["sksj", "classTime", "schedule", "time"])
            ?? Self.makeClassTime(from: dictionary)

        guard let displayClassTime = Self.displayText(classTime) else
        {
            // 没有可验证的星期 / 节次就不写入空闲度；宁可少显示，也不能凭颜色猜。
            return nil
        }

        self.courseID = courseID
        self.courseCode = courseCode
        self.courseName = Self.displayText(courseName) ?? "课表安排"
        self.parentTeachingClassID = parentTeachingClassID
        self.teachingClassID = teachingClassID
        self.teachingClassName = teachingClassName
        self.teacher = teacher
        self.classTime = displayClassTime
        self.location = location
    }

    private static func collectRows(from object: Any, into rows: inout [[String: Any]])
    {
        if let array = object as? [Any]
        {
            for item in array
            {
                collectRows(from: item, into: &rows)
            }
            return
        }

        guard let dictionary = object as? [String: Any] else { return }
        let rowKeys = ["kcmc", "jxbmc", "jxb_id", "fjxb_id", "sksj", "xqjmc", "xqj", "jc", "jcs"]
        if rowKeys.contains(where: { dictionary[$0] != nil })
        {
            rows.append(dictionary)
        }

        // 兼容正方常见的顶层和嵌套列表名称；只向已知容器递归，避免把 queryModel
        // 等配置对象误当成排课数据。
        for key in ["tmpList", "kbList", "items", "rows", "data", "list", "result", "results"]
        {
            if let nested = dictionary[key]
            {
                collectRows(from: nested, into: &rows)
            }
        }
    }

    private static func firstString(in dictionary: [String: Any], keys: [String]) -> String?
    {
        for key in keys
        {
            if let text = stringValue(dictionary[key]), displayText(text) != nil
            {
                return text
            }
        }
        return nil
    }

    private static func stringValue(_ value: Any?) -> String?
    {
        switch value
        {
        case let value as String:
            return value
        case let value as NSNumber:
            return value.stringValue
        case let value as [Any]:
            let values = value.compactMap { stringValue($0) }
            return values.isEmpty ? nil : values.joined(separator: ",")
        default:
            return nil
        }
    }

    private static func makeClassTime(from dictionary: [String: Any]) -> String?
    {
        let weekday = firstString(in: dictionary, keys: ["xqjmc", "weekday", "dayName"])
            ?? weekdayName(from: firstString(in: dictionary, keys: ["xqj", "day", "weekdayNumber"]))
        guard let weekday = displayText(weekday) else { return nil }

        let rawPeriods = firstString(in: dictionary, keys: ["jc", "jcs", "period", "classPeriod"])
        guard let periods = displayPeriods(rawPeriods) else { return nil }

        let rawWeeks = firstString(in: dictionary, keys: ["zcd", "zcmc", "week", "weeks", "weekText"])
        let weeks = displayText(rawWeeks)
        let weekSuffix: String
        if let weeks, weeks.contains("周")
        {
            weekSuffix = "{\(weeks)}"
        }
        else if let weeks
        {
            weekSuffix = "{\(weeks)周}"
        }
        else
        {
            weekSuffix = ""
        }
        return "\(weekday)第\(periods)节\(weekSuffix)"
    }

    private static func weekdayName(from rawValue: String?) -> String?
    {
        guard let number = Int(rawValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") else { return nil }
        let names = [1: "星期一", 2: "星期二", 3: "星期三", 4: "星期四", 5: "星期五", 6: "星期六", 7: "星期日"]
        return names[number]
    }

    private static func displayPeriods(_ rawValue: String?) -> String?
    {
        guard let rawValue = displayText(rawValue) else { return nil }
        let cleaned = rawValue
            .replacingOccurrences(of: "第", with: "")
            .replacingOccurrences(of: "节", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // 一些 ZF 课表接口以 0102 / 01020304 表示节次，转成可复用的 1-2 / 1-4。
        if cleaned.range(of: #"^\d{4,}$"#, options: .regularExpression) != nil,
           cleaned.count.isMultiple(of: 2)
        {
            let numbers = stride(from: 0, to: cleaned.count, by: 2).compactMap
            { offset -> Int? in
                let start = cleaned.index(cleaned.startIndex, offsetBy: offset)
                let end = cleaned.index(start, offsetBy: 2)
                return Int(cleaned[start ..< end])
            }
            guard let first = numbers.first, let last = numbers.last else { return nil }
            return first == last ? String(first) : "\(first)-\(last)"
        }
        return cleaned
    }

    private static func displayText(_ value: String?) -> String?
    {
        guard let value else { return nil }
        let text = value
            .replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty || text == "--" ? nil : text
    }

    private static func identifiersMatch(_ first: String?, _ second: String?) -> Bool
    {
        let first = normalizedIdentifier(first)
        let second = normalizedIdentifier(second)
        return !first.isEmpty && first == second
    }

    private static func normalizedIdentifier(_ value: String?) -> String
    {
        (value ?? "")
            .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
            .lowercased()
    }

    private static func usableIdentifier(_ value: String?) -> String
    {
        let normalized = normalizedIdentifier(value)
        return ["", "0", "-1"].contains(normalized) ? "" : normalized
    }
}

/// 将“选课列表”与“真实课表”合并后的结果。`unmatched` 仍会进入空闲度概览，
/// 但不会伪装成可退选的课程卡片。
struct SelectedCourseScheduleMergeResult
{
    let courses: [SelectedCourse]
    let unmatched: [SelectedCourseScheduleEntry]
}

enum SelectedCourseScheduleQueryError: LocalizedError
{
    case invalidURL
    case invalidResponse
    case sessionExpired
    case serverError(Int)

    var errorDescription: String?
    {
        switch self
        {
        case .invalidURL:
            return "课表补充查询地址无效。"
        case .invalidResponse:
            return "教务系统返回了无法识别的课表补充数据。"
        case .sessionExpired:
            return "教务登录状态已失效，请重新登录后再试。"
        case let .serverError(statusCode):
            return "教务系统暂时无法读取课表补充信息（状态码 \(statusCode)）。"
        }
    }
}
