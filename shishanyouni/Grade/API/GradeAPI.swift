import Foundation

class GradeAPI
{
    private let backendSession: ShishanyouniV3Session

    init(backendSession: ShishanyouniV3Session = .shared)
    {
        self.backendSession = backendSession
    }

    /// V3 只请求一个学期；全学年与所有成绩由 ShishanyouniGradeService 合并。
    func fetchSemesterGrades(
        username: String, encryptedPassword: String, xnm: String, xqm: String,
        mfa: ShishanyouniV3MFAProvider? = nil
    ) async throws -> [Grade]
    {
        guard !xnm.isEmpty, ["1", "2"].contains(xqm) else { throw ShishanyouniV3Error.invalidParameters }
        let data = try await backendSession.request(
            .score, username: username, encryptedPassword: encryptedPassword,
            parameters: ["xnm": xnm, "xqm": xqm], mfa: mfa
        )
        let decoded = try JSONDecoder().decode(LionGradeResponse.self, from: data)
        return (decoded.data ?? []).map
        { grade in
            var value = grade
            value.querySource = .shishanyouni
            if value.xnm?.isEmpty != false { value.xnm = xnm }
            if value.xqm?.isEmpty != false { value.xqm = xqm }
            return value
        }
    }

    /// 从教务系统查询成绩。这个接口保留成绩明细所需的查询上下文。
    func fetchGradesFromTeachingSystem(cookie: String, xnm: String, xqm: String) async throws -> [Grade]
    {
        guard let url = URL(string: SchoolDirectAPI.gradeListURL) else
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

        var components = URLComponents(string: SchoolDirectAPI.gradeDetailURL)
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
        request.setValue(SchoolDirectAPI.teachingSystemOrigin, forHTTPHeaderField: "Origin")
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
        request.setValue(SchoolDirectAPI.gradeReferer, forHTTPHeaderField: "Referer")
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
        return text.contains(SchoolDirectAPI.casLoginResponseMarker)
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
