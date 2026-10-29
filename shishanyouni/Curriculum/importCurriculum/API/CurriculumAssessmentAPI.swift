import Foundation

/// 考核方式的 HTTP 请求；课程匹配规则位于 CurriculumAssessmentService。
enum CurriculumAssessmentAPI
{
    static func fetchTimetable(cookie: String, year: String, academicTerm: String) async throws -> Data
    {
        guard let url = URL(string: SchoolDirectAPI.timetableURL) else
        {
            throw CurriculumAssessmentError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148", forHTTPHeaderField: "User-Agent")
        request.setValue(SchoolDirectAPI.timetableReferer, forHTTPHeaderField: "Referer")
        request.setValue(SchoolDirectAPI.academicOrigin, forHTTPHeaderField: "Origin")
        request.setValue(cookie, forHTTPHeaderField: "Cookie")

        // 不传 `zs`，本研教学一体化平台才会返回整学期，而不是只返回某一周。
        let encodedYear = formEncode(year)
        let encodedTerm = formEncode(academicTerm)
        request.httpBody = "xnm=\(encodedYear)&xqm=\(encodedTerm)&doType=app&kblx="
            .data(using: .utf8)

        let (data, response) = try await NetworkService.perform(request: request)
        guard let http = response as? HTTPURLResponse else
        {
            throw CurriculumAssessmentError.invalidResponse
        }
        guard http.statusCode == 200 else
        {
            throw CurriculumAssessmentError.httpError(http.statusCode)
        }

        return data
    }

    private static func formEncode(_ value: String) -> String
    {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

}
