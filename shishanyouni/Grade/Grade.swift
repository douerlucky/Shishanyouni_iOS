//
//  Grade.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/6.
//

import Foundation

/// 成绩查询的数据来源。
///
/// 狮山有你接口适合快速查询；教务系统接口会额外返回 `xh_id`、`xnm`、`xqm`，
/// 这些字段正是“成绩明细”接口需要的上下文。
enum GradeQuerySource: String, QuerySourceOption, Codable
{
    case teachingSystem = "teachingSystem"
    case shishanyouni = "shishanyouni"

    var id: String { rawValue }

    var title: String
    {
        switch self
        {
        case .teachingSystem: return "教务系统"
        case .shishanyouni: return "狮山有你"
        }
    }
}

struct TeachingSystemGradeResponse: Decodable
{
    let items: [Grade]
}

struct LionGradeResponse: Decodable
{
    let msg: String?
    let code: Int?
    let data: [Grade]?
    let timestamp: Int64?
    let success: Bool?
    let fail: Bool?
}

struct Grade: Identifiable, Codable
{
    let jxb_id: String
    var id: String { jxb_id }

    let kcmc: String       // 课程名称
    let kcxzmc: String?    // 课程性质（必修 / 选修）
    let xf: String         // 学分
    let cj: String         // 成绩
    let jd: String         // 绩点
    let khfsmc: String?    // 考核方式（考试 / 考查）
    let kcgsmc: String?    // 课程归属名称
    let xm: String?        // 学生姓名
    let bj: String?        // 班级
    let kch: String?       // 课程号
    let jsxm: String?      // 教师姓名
    let kkbmmc: String?    // 开课部门
    let xnmmc: String?     // 学年名称（如 2025-2026）
    let xqmmc: String?     // 学期名称
    let detail: String?
    let bfzcj: String?     // 百分制成绩

    // 下面三个字段只由教务系统成绩接口提供；旧缓存没有这些字段时会自动解码为 nil。
    let xh_id: String?
    var xnm: String?
    var xqm: String?

    /// 旧版缓存没有来源字段，默认按“狮山有你”处理，避免旧成绩突然被当成教务系统成绩。
    var querySource: GradeQuerySource?

    var effectiveQuerySource: GradeQuerySource
    {
        querySource ?? .shishanyouni
    }

}

/// 教务系统成绩组成项，例如“平时成绩 / 期中成绩 / 期末成绩”。
struct GradeComponent: Identifiable, Equatable
{
    let name: String
    let percentageText: String?
    let scoreText: String

    var id: String { "\(name)|\(percentageText ?? "")|\(scoreText)" }

    var percentageValue: Double?
    {
        guard let percentageText else { return nil }
        let number = percentageText.filter { $0.isNumber || $0 == "." }
        return Double(number)
    }

    var scoreValue: Double?
    {
        let number = scoreText.filter { $0.isNumber || $0 == "." }
        return Double(number)
    }

    /// 把百分制分数转换成圆环中 0...1 的填充比例。
    var normalizedScore: Double
    {
        min(max((scoreValue ?? 0) / 100, 0), 1)
    }

    var isOverallScore: Bool
    {
        name.contains("总评") || name.contains("总成绩")
    }
}

enum GradeQueryError: LocalizedError
{
    case invalidURL
    case invalidResponse
    case emptyResponse
    case httpStatus(Int)
    case sessionUnavailable
    case invalidDetailContext
    case invalidDetailHTML

    var errorDescription: String?
    {
        switch self
        {
        case .invalidURL:
            return "成绩查询地址无效。"
        case .invalidResponse:
            return "成绩接口返回了无法识别的响应。"
        case .emptyResponse:
            return "成绩接口返回了空数据。"
        case let .httpStatus(code):
            return code == 901
                ? "教务系统登录状态已失效，请重新查询成绩后再试。"
                : "成绩查询失败，教务系统返回状态码 \(code)。"
        case .sessionUnavailable:
            return "当前没有可用的教务系统会话，请先用“教务系统”数据源查询一次成绩。"
        case .invalidDetailContext:
            return "这门课程缺少成绩明细查询参数。"
        case .invalidDetailHTML:
            return "没有从教务系统响应中解析到成绩明细。"
        }
    }
}

class GradeService
{
    private let baseURL = "https://lion.hzau.edu.cn/app/ios/score"
    private let teachingSystemGradeURL = "http://jwgl.hzau.edu.cn/cjcx/cjcx_cxXsgrcj.html?doType=query&gnmkdm=N305005"
    private let teachingSystemDetailURL = "http://jwgl.hzau.edu.cn/cjcx/cjcx_cxCjxqGjh.html"
    private let teachingSystemReferer = "http://jwgl.hzau.edu.cn/cjcx/cjcx_cxDgXscj.html?gnmkdm=N305005&layout=default"

    /// xnm: 学年开始年份（如 "2025" 代表 2025-2026 学年）
    /// xqm: 学期（"1" 第一学期，"2" 第二学期，"0" 全学年）
    func fetchGrades(username: String, password: String, token: String = "", xnm: String, xqm: String) async throws -> [Grade]
    {
        guard let url = URL(string: baseURL) else
        {
            throw NSError(domain: "GradeService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "URL 构建失败"])
        }

        // 构建 JSON body
        var body: [String: Any] = [
            "xnm":  xnm,
            "xqm":  xqm,
            "yhm":  username,
            "mm":   password,
            // 按 lion /app/ios/score 当前请求示例使用 type=0；xqm=0 可查询学年或全部学年成绩。
            "type": 0
        ]
        if !token.isEmpty
        {
            body["token"] = token
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await NetworkService.perform(request: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else
        {
            throw NSError(domain: "GradeService", code: 500,
                          userInfo: [NSLocalizedDescriptionKey: "网络请求失败"])
        }

        try ShishanyouniAPIError.throwIfMFAResponse(data)

        let decoded = try JSONDecoder().decode(LionGradeResponse.self, from: data)

        guard decoded.success == true || decoded.code == 2 || decoded.code == 200 else
        {
            let msg = decoded.msg ?? "服务器返回未知错误"
            throw ShishanyouniAPIError.apiError(code: decoded.code, message: msg)
        }

        return decoded.data ?? []
    }

    /// 从教务系统查询成绩。这个接口保留成绩明细所需的查询上下文。
    func fetchGradesFromTeachingSystem(cookie: String, xnm: String, xqm: String) async throws -> [Grade]
    {
        guard let url = URL(string: teachingSystemGradeURL) else
        {
            throw GradeQueryError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyTeachingSystemHeaders(
            to: &request,
            cookie: cookie,
            accept: "application/json, text/javascript, */*; q=0.01"
        )
        request.httpBody = formBody([
            ("xnm", xnm),
            ("xqm", xqm),
            ("_kb", String(Int64(Date().timeIntervalSince1970 * 1000))),
            ("queryModel.showCount", "300"),
            ("queryModel.currentPage", "1"),
            ("queryModel.sortName", ""),
            ("queryModel.sortOrder", "asc"),
        ])

        let (data, response) = try await NetworkService.perform(request: request)
        if let http = response as? HTTPURLResponse
        {
            // 只记录状态和最终 URL，不记录 Cookie、账号或成绩内容。
            print("[Grade][Teaching] status=\(http.statusCode) url=\(http.url?.absoluteString ?? "nil") bytes=\(data.count) contentType=\(http.value(forHTTPHeaderField: "Content-Type") ?? "nil")")
        }
        try validateTeachingSystemResponse(data: data, response: response)

        do
        {
            let decoded = try JSONDecoder().decode(TeachingSystemGradeResponse.self, from: data)
            return decoded.items.map
            { grade in
                var teachingGrade = grade
                teachingGrade.querySource = .teachingSystem
                // 有些教务响应不回传学年/学期；补上本次请求上下文，
                // 后续点“成绩明细”时才能准确回到对应学期。
                if teachingGrade.xnm?.isEmpty != false { teachingGrade.xnm = xnm }
                if teachingGrade.xqm?.isEmpty != false { teachingGrade.xqm = xqm }
                return teachingGrade
            }
        }
        catch
        {
            if responseLooksLikeLoginPage(data)
            {
                throw GradeQueryError.httpStatus(901)
            }
            throw error
        }
    }

    /// 教务系统没有可靠的“全学年”成绩参数，因此固定分别查询第一、第二学期并合并。
    /// 两次请求串行执行，避免同一 JSESSIONID 的并发请求被旧教务系统互相干扰。
    func fetchAllYearGradesFromTeachingSystem(cookie: String, xnm: String) async throws -> [Grade]
    {
        let firstTerm = try await fetchGradesFromTeachingSystem(cookie: cookie, xnm: xnm, xqm: "3")
        let secondTerm = try await fetchGradesFromTeachingSystem(cookie: cookie, xnm: xnm, xqm: "12")

        var seen = Set<String>()
        return (firstTerm + secondTerm).filter
        { grade in
            let key = "\(grade.jxb_id)|\(grade.xnm ?? xnm)|\(grade.xqm ?? "")"
            return seen.insert(key).inserted
        }
    }

    /// 请求单门课程的成绩组成明细。明细 HTML 只在点击课程后按需加载。
    func fetchGradeComponents(
        for grade: Grade,
        cookie: String?,
        fallbackStudentID: String,
        fallbackYear: String,
        fallbackTerm: String
    ) async throws -> [GradeComponent]
    {
        guard let cookie, !cookie.isEmpty else
        {
            throw GradeQueryError.sessionUnavailable
        }
        // 是否显示入口由 GradeInquiry 的当前数据源决定；这里仅校验接口真正需要的课程 ID。
        guard !grade.jxb_id.isEmpty else
        {
            throw GradeQueryError.invalidDetailContext
        }
        let studentID = grade.xh_id?.isEmpty == false ? grade.xh_id! : fallbackStudentID
        guard !studentID.isEmpty else
        {
            throw GradeQueryError.invalidDetailContext
        }

        var components = URLComponents(string: teachingSystemDetailURL)
        components?.queryItems = [
            URLQueryItem(name: "time", value: String(Int64(Date().timeIntervalSince1970 * 1000))),
            URLQueryItem(name: "gnmkdm", value: "N305005"),
        ]
        guard let url = components?.url else
        {
            throw GradeQueryError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyTeachingSystemHeaders(to: &request, cookie: cookie, accept: "text/html, */*; q=0.01")
        request.setValue("http://jwgl.hzau.edu.cn", forHTTPHeaderField: "Origin")
        request.httpBody = formBody([
            ("jxb_id", grade.jxb_id),
            ("xnm", grade.xnm ?? fallbackYear),
            ("xqm", grade.xqm ?? fallbackTerm),
            ("xh_id", studentID),
            ("kcmc", grade.kcmc),
        ])

        let (data, response) = try await NetworkService.perform(request: request)
        try validateTeachingSystemResponse(data: data, response: response)
        guard let html = String(data: data, encoding: .utf8) else
        {
            throw GradeQueryError.invalidDetailHTML
        }
        if responseLooksLikeLoginPage(data)
        {
            throw GradeQueryError.httpStatus(901)
        }

        let result = parseGradeComponents(from: html)
        guard !result.isEmpty else
        {
            throw GradeQueryError.invalidDetailHTML
        }
        return result
    }

    private func applyTeachingSystemHeaders(to request: inout URLRequest, cookie: String, accept: String)
    {
        request.setValue("application/x-www-form-urlencoded;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue(teachingSystemReferer, forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148", forHTTPHeaderField: "User-Agent")
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
    }

    private func validateTeachingSystemResponse(data: Data, response: URLResponse) throws
    {
        guard let http = response as? HTTPURLResponse else
        {
            throw GradeQueryError.invalidResponse
        }
        guard http.statusCode == 200 else
        {
            throw GradeQueryError.httpStatus(http.statusCode)
        }
        guard !data.isEmpty else
        {
            throw GradeQueryError.emptyResponse
        }
    }

    private func responseLooksLikeLoginPage(_ data: Data) -> Bool
    {
        guard let text = String(data: data, encoding: .utf8)?.lowercased() else { return false }
        return text.contains("cas-paas.hzau.edu.cn/cas/login")
            || text.contains("name=\"execution\"")
            || text.contains("统一身份认证")
    }

    private func formBody(_ items: [(String, String)]) -> Data?
    {
        items
            .map { "\(formEncode($0.0))=\(formEncode($0.1))" }
            .joined(separator: "&")
            .data(using: .utf8)
    }

    private func formEncode(_ value: String) -> String
    {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    /// 解析教务系统返回的表格行，兼容平时、期中、实验、期末等任意分项。
    private func parseGradeComponents(from html: String) -> [GradeComponent]
    {
        guard let rowRegex = try? NSRegularExpression(
            pattern: #"<tr\b[^>]*>(.*?)</tr>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ), let cellRegex = try? NSRegularExpression(
            pattern: #"<td\b[^>]*>(.*?)</td>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return [] }

        let fullRange = NSRange(html.startIndex..., in: html)
        return rowRegex.matches(in: html, range: fullRange).compactMap
        { rowMatch in
            guard let rowRange = Range(rowMatch.range(at: 1), in: html) else { return nil }
            let rowHTML = String(html[rowRange])
            let cells = cellRegex.matches(
                in: rowHTML,
                range: NSRange(rowHTML.startIndex..., in: rowHTML)
            ).compactMap
            { cellMatch -> String? in
                guard let range = Range(cellMatch.range(at: 1), in: rowHTML) else { return nil }
                return cleanHTMLText(String(rowHTML[range]))
            }

            guard cells.count >= 3 else { return nil }
            let name = cells[0]
                .replacingOccurrences(of: "【", with: "")
                .replacingOccurrences(of: "】", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !name.contains("成绩分项") else { return nil }
            let percentage = cells[1].isEmpty ? nil : cells[1]
            guard !cells[2].isEmpty else { return nil }
            return GradeComponent(name: name, percentageText: percentage, scoreText: cells[2])
        }
    }

    private func cleanHTMLText(_ html: String) -> String
    {
        let withoutTags = html.replacingOccurrences(
            of: #"<[^>]+>"#,
            with: "",
            options: .regularExpression
        )
        return withoutTags
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#160;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
