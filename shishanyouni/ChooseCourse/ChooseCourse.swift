//
//  ChooseCourse.swift
//  shishanyouni
//
//  已选课程的数据模型与只读查询。
//  选课/退选写请求位于 CourseEdit.swift，避免列表刷新意外改变教务系统状态。
//

import Foundation

struct SelectedCourse: Identifiable, Decodable
{
    let teachingClassID: String
    /// `cxZkcZzxkYzb` 用 `fjxb_id` 把实验/子教学班挂回主教学班。
    /// 根教学班没有父 ID 时，回退到本行的 `jxb_id`。
    let parentTeachingClassID: String
    let teachingClassName: String?
    let courseCode: String?
    let courseName: String
    let courseType: String?
    let teacherInfo: String?
    let location: String?
    let classTime: String?
    let credit: String?
    let selectedCount: String?
    let capacity: String?
    /// 课表模块补回的实验 / 上机等实际安排。它们仅供展示与空闲度计算，
    /// 不参与退选 token、人数或课程学分的判断。
    let supplementalSchedules: [SelectedCourseScheduleEntry]

    /// 以下字段不显示在界面，用于退选前重新核验当前页面参数。
    /// 它们只在内存中保留，绝不写入日志或 UserDefaults。
    let courseID: String
    let selectionTokens: [String]
    let dropAllowed: Bool
    let selectionContext: CourseSelectionContext
    let selectionCaption: String

    var id: String
    {
        let trimmedID = teachingClassID.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedID.isEmpty { return trimmedID }
        return [courseCode ?? courseName, teachingClassName ?? ""].joined(separator: "-")
    }

    var teacherName: String
    {
        let parts = teacherInfo?
            .split(separator: "/", omittingEmptySubsequences: false)
            .map(String.init) ?? []

        if parts.count >= 2, let name = Self.displayText(parts[1])
        {
            return name
        }
        return Self.displayText(teacherInfo) ?? "暂未提供"
    }

    var enrollmentText: String?
    {
        guard let selected = Self.displayText(selectedCount),
              let total = Self.displayText(capacity)
        else { return nil }
        return "已选 \(selected)/\(total)"
    }

    var displayLocation: String? { Self.displayText(location) }
    var displayClassTime: String? { Self.displayText(classTime) }
    var displayCourseType: String? { Self.displayText(courseType) }
    var displayCredit: String? { Self.displayText(credit) }
    var displayTeachingClassName: String? { Self.displayText(teachingClassName) }
    var displayCourseCode: String? { Self.displayText(courseCode) }

    private enum CodingKeys: String, CodingKey
    {
        case teachingClassID = "jxb_id"
        case parentTeachingClassID = "fjxb_id"
        case teachingClassName = "jxbmc"
        case courseCode = "kch"
        case courseName = "kcmc"
        case courseType = "kklxmc"
        case teacherInfo = "jsxx"
        case location = "jxdd"
        case classTime = "sksj"
        case credit = "xf"
        case selectedCount = "jxbrs"
        case capacity = "jxbrl"
        case courseID = "kch_id"
    }

    init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dynamicContainer = try decoder.container(keyedBy: DynamicCodingKey.self)
        teachingClassID = container.stringValue(forKey: .teachingClassID) ?? ""
        let rawParentID = ["fjxb_id", "fjxbId", "parent_jxb_id", "parentJxbId"]
            .compactMap { dynamicContainer.stringValue(forKey: DynamicCodingKey(stringValue: $0)) }
            .first(where: { Self.isUsableParentID($0) })
        parentTeachingClassID = rawParentID ?? teachingClassID
        teachingClassName = container.stringValue(forKey: .teachingClassName)
        courseCode = container.stringValue(forKey: .courseCode)
        courseName = container.stringValue(forKey: .courseName) ?? "未命名课程"
        courseType = container.stringValue(forKey: .courseType)
        teacherInfo = container.stringValue(forKey: .teacherInfo)
        location = container.stringValue(forKey: .location)
        classTime = container.stringValue(forKey: .classTime)
        credit = container.stringValue(forKey: .credit)
        // 子教学班和已选列表都以 jxbrs / jxbrl 表示“已选 / 容量”；旧版本
        // 可能只给 yxzrs，因此只把它作为已选人数的回退，不能误当容量。
        selectedCount = container.stringValue(forKey: .selectedCount)
            ?? dynamicContainer.stringValue(forKey: DynamicCodingKey(stringValue: "yxzrs"))
        capacity = container.stringValue(forKey: .capacity)
            ?? dynamicContainer.stringValue(forKey: DynamicCodingKey(stringValue: "kyrs"))

        // ChoosedDisplay 中的 do_jxb_id / jxb_ids 是本次会话签发的退选参数；
        // 不根据 jxb_id 或课程号伪造，缺失时 CourseEdit 会安全地阻止退选。
        courseID = container.stringValue(forKey: .courseID) ?? courseCode ?? ""
        selectionTokens = Self.selectionTokens(
            from: ["jxb_ids", "jxbids", "do_jxb_id", "doJxbId"].compactMap
            { dynamicContainer.stringValue(forKey: DynamicCodingKey(stringValue: $0)) }
        )
        // 网页的退选按钮条件是 `sfktk == 1 && tktjrs < jxbrs`。字段既可能是
        // 字符串，也可能是数字 / 布尔值；缺少人数时只按 sfktk 回退，避免误判可退课。
        dropAllowed = Self.canDrop(
            flag: dynamicContainer.stringValue(forKey: DynamicCodingKey(stringValue: "sfktk")),
            minimumSelectedCount: dynamicContainer.stringValue(forKey: DynamicCodingKey(stringValue: "tktjrs")),
            currentSelectedCount: selectedCount
        )
        selectionCaption = ["kcmc_xk", "kcmc_display", "kcmcDisplay", "kcmc"]
            .compactMap { dynamicContainer.stringValue(forKey: DynamicCodingKey(stringValue: $0)) }
            .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? courseName

        var contextValues: [String: String] = [:]
        for field in CourseSelectionContext.responseFields
        {
            guard let value = dynamicContainer.stringValue(forKey: DynamicCodingKey(stringValue: field)),
                  !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { continue }
            contextValues[field == "jg_id_1" ? "jg_id" : field] = value
        }
        selectionContext = CourseSelectionContext(values: contextValues)
        supplementalSchedules = []
    }

    private static func displayText(_ value: String?) -> String?
    {
        guard let value else { return nil }
        let trimmed = value
            .replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "--" ? nil : trimmed
    }

    private static func isAffirmativeFlag(_ value: String?) -> Bool
    {
        guard let value else { return false }
        return ["1", "true", "yes", "ok", "success"]
            .contains(value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    private static func canDrop(
        flag: String?,
        minimumSelectedCount: String?,
        currentSelectedCount: String?
    ) -> Bool
    {
        guard isAffirmativeFlag(flag) else { return false }
        guard let minimum = wholeNumber(minimumSelectedCount),
              let selected = wholeNumber(currentSelectedCount)
        else {
            return true
        }
        return minimum < selected
    }

    private static func wholeNumber(_ value: String?) -> Int?
    {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let number = Int(normalized) { return number }
        if let number = Double(normalized), number.rounded() == number { return Int(number) }
        return nil
    }

    private static func selectionTokens(from rawValues: [String]) -> [String]
    {
        var tokens: [String] = []
        for rawValue in rawValues
        {
            // 临时教学班参数是长十六进制串。只接受服务端明确返回的这种格式，
            // 不把 jxb_id、课程号等普通字段误当成可用于退选的参数。
            let pattern = #"(?i)(?<![0-9a-f])[0-9a-f]{48,}(?![0-9a-f])"#
            guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(rawValue.startIndex ..< rawValue.endIndex, in: rawValue)
            for match in expression.matches(in: rawValue, range: range)
            {
                guard let tokenRange = Range(match.range, in: rawValue) else { continue }
                let token = String(rawValue[tokenRange])
                if !tokens.contains(token)
                {
                    tokens.append(token)
                }
            }
        }
        return tokens
    }

    /// 同一门课在 ChoosedDisplay 中可能按层级拆成多行。
    /// 合并后才交给退选流程，确保 `jxb_ids` 完全来自这次刷新返回的所有 token。
    static func mergeServerRows(_ rows: [SelectedCourse]) -> [SelectedCourse]
    {
        var merged: [SelectedCourse] = []
        var indexes: [String: Int] = [:]

        for row in rows
        {
            let identity = row.courseID.ifEmpty(row.courseCode ?? row.teachingClassID)
            guard !identity.isEmpty else
            {
                merged.append(row)
                continue
            }

            if let index = indexes[identity]
            {
                merged[index] = merged[index].merging(row)
            }
            else
            {
                indexes[identity] = merged.count
                merged.append(row)
            }
        }
        return merged
    }

    /// 已选接口和课表接口职责不同：前者决定课程是否已选、能否退选，后者补齐真实排课。
    /// 只把能精确对应到某门已选课的记录挂在课程卡片上；无法对应的记录单独返回，
    /// 仍可用于空闲度概览，但绝不会被伪装成可退选课程。
    static func mergingScheduleEntries(
        _ entries: [SelectedCourseScheduleEntry],
        into courses: [SelectedCourse]
    ) -> SelectedCourseScheduleMergeResult
    {
        var mergedCourses = courses
        var unmatched: [SelectedCourseScheduleEntry] = []

        for entry in entries
        {
            guard let index = mergedCourses.firstIndex(where: { entry.belongs(to: $0) }) else
            {
                unmatched.append(entry)
                continue
            }
            mergedCourses[index] = mergedCourses[index].addingSupplementalSchedule(entry)
        }

        return SelectedCourseScheduleMergeResult(courses: mergedCourses, unmatched: unmatched)
    }

    /// 主教学班的展示字段与课表补充字段统一交给空闲度解析器，避免子班漏算。
    var availabilitySchedules: [SelectedCourseScheduleEntry]
    {
        var entries: [SelectedCourseScheduleEntry] = []
        if let mainSchedule = SelectedCourseScheduleEntry(course: self)
        {
            entries.append(mainSchedule)
        }
        for entry in supplementalSchedules where !entries.contains(entry)
        {
            entries.append(entry)
        }
        return entries
    }

    private func merging(_ other: SelectedCourse) -> SelectedCourse
    {
        var allTokens = selectionTokens
        for token in other.selectionTokens where !allTokens.contains(token)
        {
            allTokens.append(token)
        }

        return SelectedCourse(
            teachingClassID: teachingClassID,
            parentTeachingClassID: mergedParentTeachingClassID(with: other),
            teachingClassName: teachingClassName,
            courseCode: courseCode,
            courseName: courseName,
            courseType: courseType,
            teacherInfo: teacherInfo,
            // 同一门课可能同时返回主教学班与子教学班；两边的上课时间、地点都要
            // 合并，否则空闲度概览会漏掉实验 / 上机等子班安排。
            location: Self.mergingScheduleText(location, with: other.location),
            classTime: Self.mergingScheduleText(classTime, with: other.classTime),
            credit: credit,
            selectedCount: selectedCount,
            capacity: capacity,
            supplementalSchedules: supplementalSchedules + other.supplementalSchedules,
            courseID: courseID,
            selectionTokens: allTokens,
            // 每一行都明确允许退选，才允许把合并后的课程交给写操作。
            dropAllowed: dropAllowed && other.dropAllowed,
            selectionContext: selectionContext.merged(with: other.selectionContext),
            selectionCaption: selectionCaption.ifEmpty(other.selectionCaption)
        )
    }

    private func addingSupplementalSchedule(_ entry: SelectedCourseScheduleEntry) -> SelectedCourse
    {
        guard !availabilitySchedules.contains(entry) else { return self }
        return SelectedCourse(
            teachingClassID: teachingClassID,
            parentTeachingClassID: parentTeachingClassID,
            teachingClassName: teachingClassName,
            courseCode: courseCode,
            courseName: courseName,
            courseType: courseType,
            teacherInfo: teacherInfo,
            location: location,
            classTime: classTime,
            credit: credit,
            selectedCount: selectedCount,
            capacity: capacity,
            supplementalSchedules: supplementalSchedules + [entry],
            courseID: courseID,
            selectionTokens: selectionTokens,
            dropAllowed: dropAllowed,
            selectionContext: selectionContext,
            selectionCaption: selectionCaption
        )
    }

    /// 保留服务端以 `<br>` 分隔的时段顺序，才能继续和同顺序的地点逐项配对。
    private static func mergingScheduleText(_ first: String?, with second: String?) -> String?
    {
        let first = first?.trimmingCharacters(in: .whitespacesAndNewlines)
        let second = second?.trimmingCharacters(in: .whitespacesAndNewlines)

        switch (first?.isEmpty == false ? first : nil, second?.isEmpty == false ? second : nil)
        {
        case let (first?, second?) where first != second:
            return "\(first)<br/>\(second)"
        case let (first?, _):
            return first
        case let (_, second?):
            return second
        default:
            return nil
        }
    }

    /// 合并同一课程的多行响应时，优先保留明确的父教学班 ID；根行只有自身
    /// `jxb_id` 时，再采用另一行返回的 `fjxb_id`。
    private func mergedParentTeachingClassID(with other: SelectedCourse) -> String
    {
        let ownIsRoot = parentTeachingClassID == teachingClassID || parentTeachingClassID.isEmpty
        if ownIsRoot, other.parentTeachingClassID != other.teachingClassID,
           !other.parentTeachingClassID.isEmpty
        {
            return other.parentTeachingClassID
        }
        return parentTeachingClassID.ifEmpty(other.parentTeachingClassID)
    }

    private static func isUsableParentID(_ value: String) -> Bool
    {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !normalized.isEmpty && normalized != "0" && normalized != "-1"
    }

    private init(
        teachingClassID: String,
        parentTeachingClassID: String,
        teachingClassName: String?,
        courseCode: String?,
        courseName: String,
        courseType: String?,
        teacherInfo: String?,
        location: String?,
        classTime: String?,
        credit: String?,
        selectedCount: String?,
        capacity: String?,
        supplementalSchedules: [SelectedCourseScheduleEntry] = [],
        courseID: String,
        selectionTokens: [String],
        dropAllowed: Bool,
        selectionContext: CourseSelectionContext,
        selectionCaption: String
    )
    {
        self.teachingClassID = teachingClassID
        self.parentTeachingClassID = parentTeachingClassID.ifEmpty(teachingClassID)
        self.teachingClassName = teachingClassName
        self.courseCode = courseCode
        self.courseName = courseName
        self.courseType = courseType
        self.teacherInfo = teacherInfo
        self.location = location
        self.classTime = classTime
        self.credit = credit
        self.selectedCount = selectedCount
        self.capacity = capacity
        self.supplementalSchedules = supplementalSchedules
        self.courseID = courseID
        self.selectionTokens = selectionTokens
        self.dropAllowed = dropAllowed
        self.selectionContext = selectionContext
        self.selectionCaption = selectionCaption
    }
}

private struct DynamicCodingKey: CodingKey
{
    let stringValue: String
    let intValue: Int? = nil

    init(stringValue: String)
    {
        self.stringValue = stringValue
    }

    init?(intValue: Int)
    {
        return nil
    }
}

private extension KeyedDecodingContainer
{
    /// 教务接口大多返回字符串，但个别学校版本会把人数等字段改为数值。
    func stringValue(forKey key: Key) -> String?
    {
        if let value = try? decode(String.self, forKey: key) { return value }
        if let value = try? decode(Int.self, forKey: key) { return String(value) }
        if let value = try? decode(Double.self, forKey: key) { return String(value) }
        if let value = try? decode(Bool.self, forKey: key) { return value ? "true" : "false" }
        return nil
    }
}

struct SelectedCourseSemester: Equatable
{
    let academicYear: String
    let termCode: String

    static func current(at date: Date = Date(), calendar: Calendar = .current) -> SelectedCourseSemester
    {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)

        // 仅作页面尚未返回学期字段时的兜底。真正请求优先使用 Index / Display
        // 返回的 xkxnm / xkxqm，避免设备日期与不同账号的选课开放学期不一致。
        // 教务系统通常用 3 表示秋季、12 表示春季；春季仍属于上一学年。
        if month >= 8
        {
            return SelectedCourseSemester(academicYear: String(year), termCode: "3")
        }
        return SelectedCourseSemester(academicYear: String(year - 1), termCode: "12")
    }

    var displayName: String
    {
        let endYear = (Int(academicYear) ?? 0) + 1
        let termName: String
        switch termCode
        {
        case "3", "1": termName = "秋季学期"
        case "12", "2": termName = "春季学期"
        default: termName = "第\(termCode)学期"
        }
        return endYear > 1 ? "\(academicYear)-\(endYear) \(termName)" : "\(academicYear) \(termName)"
    }
}

enum SelectedCourseQueryError: LocalizedError
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
            return "已选课程查询地址无效。"
        case .invalidResponse:
            return "教务系统返回了无法识别的已选课程数据。"
        case .sessionExpired:
            return "教务登录状态已失效，请重新登录后再试。"
        case let .serverError(statusCode):
            return "教务系统暂时无法查询已选课程（状态码 \(statusCode)）。"
        }
    }
}

final class SelectedCourseQuery
{
    static let shared = SelectedCourseQuery()

    private let selectedCoursesURL = "http://byjxyt.hzau.edu.cn/xsxk/zzxkyzb_cxZzxkYzbChoosedDisplay.html?gnmkdm=N253512"
    private let selectedCoursesReferer = "http://byjxyt.hzau.edu.cn/xsxk/zzxkyzb_cxZzxkYzbIndex.html?gnmkdm=N253512&layout=default"

    func fetchSelectedCourses(cookie: String, semester: SelectedCourseSemester) async throws -> [SelectedCourse]
    {
        guard let url = URL(string: selectedCoursesURL) else
        {
            throw SelectedCourseQueryError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue("http://byjxyt.hzau.edu.cn", forHTTPHeaderField: "Origin")
        request.setValue(selectedCoursesReferer, forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue(cookie, forHTTPHeaderField: "Cookie")

        // 与教务网页请求体一致；学年、学期始终取本次当前账号的选课页面上下文。
        let parameters = [
            ("xkxnm", semester.academicYear),
            ("xkxqm", semester.termCode),
            ("queryModel.showCount", "100"),
            ("queryModel.currentPage", "1"),
            ("queryModel.sortName", ""),
            ("queryModel.sortOrder", "asc"),
        ]
        request.httpBody = formEncodedData(parameters)

        ChooseCourseDebug.request(
            url: url,
            method: "POST",
            parameters: parameters,
            retryCount: NetworkService.maxRetries,
            hasCookie: !cookie.isEmpty
        )
        do
        {
            let (data, response) = try await NetworkService.perform(request: request)
            guard let httpResponse = response as? HTTPURLResponse else
            {
                throw SelectedCourseQueryError.invalidResponse
            }
            ChooseCourseDebug.response(url: url, response: httpResponse, data: data)
            guard (200 ..< 300).contains(httpResponse.statusCode) else
            {
                throw SelectedCourseQueryError.serverError(httpResponse.statusCode)
            }

            let responseText = String(data: data, encoding: .utf8) ?? ""
            if responseText.contains("用户登录") || responseText.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<")
            {
                throw SelectedCourseQueryError.sessionExpired
            }

            do
            {
                let rows = try JSONDecoder().decode([SelectedCourse].self, from: data)
                let courses = SelectedCourse.mergeServerRows(rows)
                ChooseCourseDebug.info("已选课程解析完成：服务端行数=\(rows.count)，合并后课程数=\(courses.count)")
                return courses
            }
            catch
            {
                ChooseCourseDebug.error("已选课程 JSON 解析失败：\(error.localizedDescription)")
                throw SelectedCourseQueryError.invalidResponse
            }
        }
        catch
        {
            ChooseCourseDebug.requestFailed(url: url, error: error)
            throw error
        }
    }

    private func formEncodedData(_ parameters: [(String, String)]) -> Data?
    {
        let body = parameters
            .map { "\(formEncode($0.0))=\(formEncode($0.1))" }
            .joined(separator: "&")
        return body.data(using: .utf8)
    }

    private func formEncode(_ value: String) -> String
    {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
