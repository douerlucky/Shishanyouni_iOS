//
//  ChooseCourse.swift
//  shishanyouni
//
//  第一阶段只读取当前学期的已选课程；不会在这里发送选课或退选请求。
//

import Foundation

struct SelectedCourse: Identifiable, Decodable
{
    let teachingClassID: String
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
        case teachingClassName = "jxbmc"
        case courseCode = "kch"
        case courseName = "kcmc"
        case courseType = "kklxmc"
        case teacherInfo = "jsxx"
        case location = "jxdd"
        case classTime = "sksj"
        case credit = "xf"
        case selectedCount = "yxzrs"
        case capacity = "jxbrs"
    }

    init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        teachingClassID = container.stringValue(forKey: .teachingClassID) ?? ""
        teachingClassName = container.stringValue(forKey: .teachingClassName)
        courseCode = container.stringValue(forKey: .courseCode)
        courseName = container.stringValue(forKey: .courseName) ?? "未命名课程"
        courseType = container.stringValue(forKey: .courseType)
        teacherInfo = container.stringValue(forKey: .teacherInfo)
        location = container.stringValue(forKey: .location)
        classTime = container.stringValue(forKey: .classTime)
        credit = container.stringValue(forKey: .credit)
        selectedCount = container.stringValue(forKey: .selectedCount)
        capacity = container.stringValue(forKey: .capacity)
    }

    private static func displayText(_ value: String?) -> String?
    {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "--" ? nil : trimmed
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

        // 教务系统用 3 表示秋季、12 表示春季；春季仍属于上一学年。
        if month >= 8
        {
            return SelectedCourseSemester(academicYear: String(year), termCode: "3")
        }
        return SelectedCourseSemester(academicYear: String(year - 1), termCode: "12")
    }

    var displayName: String
    {
        let endYear = (Int(academicYear) ?? 0) + 1
        let termName = termCode == "3" ? "秋季学期" : "春季学期"
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

        // 与教务网页的请求体一致：2026 年秋季时长度正好为抓包中的 114 字节。
        let parameters = [
            ("xkxnm", semester.academicYear),
            ("xkxqm", semester.termCode),
            ("queryModel.showCount", "100"),
            ("queryModel.currentPage", "1"),
            ("queryModel.sortName", ""),
            ("queryModel.sortOrder", "asc"),
        ]
        request.httpBody = formEncodedData(parameters)

        let (data, response) = try await NetworkService.perform(request: request)
        guard let httpResponse = response as? HTTPURLResponse else
        {
            throw SelectedCourseQueryError.invalidResponse
        }
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
            return try JSONDecoder().decode([SelectedCourse].self, from: data)
        }
        catch
        {
            throw SelectedCourseQueryError.invalidResponse
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
