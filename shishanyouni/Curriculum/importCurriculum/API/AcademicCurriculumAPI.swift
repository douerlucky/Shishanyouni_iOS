import Foundation

/// 本研教学一体化平台的整学期课表请求，不访问狮山有你服务器。
enum AcademicCurriculumAPI
{
    static func makeRequest(cookie: String, year: String, academicTerm: String) -> URLRequest
    {
        var request = URLRequest(url: URL(string: SchoolDirectAPI.curriculumImportURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue(SchoolDirectAPI.academicTimetableReferer, forHTTPHeaderField: "Referer")
        request.setValue(SchoolDirectAPI.academicOrigin, forHTTPHeaderField: "Origin")
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "localeKey", value: "zh_CN"),
            URLQueryItem(name: "xnm", value: year),
            URLQueryItem(name: "xqm", value: academicTerm),
            // 空 zs 读取全部周次，不能把当前周当成整学期导入。
            URLQueryItem(name: "zs", value: ""),
        ]
        request.httpBody = form.percentEncodedQuery?.data(using: .utf8)
        return request
    }

    static func fetchTimetable(
        cookie: String, year: String, academicTerm: String, session: URLSession = .shared
    ) async throws -> Data
    {
        let (data, response) = try await NetworkService.perform(
            with: session, request: makeRequest(cookie: cookie, year: year, academicTerm: academicTerm)
        )
        guard let http = response as? HTTPURLResponse else { throw CurriculumError.invalidResponse }
        guard http.statusCode == 200 else { throw CurriculumError.httpError(http.statusCode) }
        if http.mimeType?.lowercased().contains("html") == true
        {
            throw CASLoginFailure.error(from: data)
        }
        return data
    }
}
