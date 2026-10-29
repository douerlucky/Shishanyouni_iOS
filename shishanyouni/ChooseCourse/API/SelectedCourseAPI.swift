import Foundation

final class SelectedCourseAPI
{
    static let shared = SelectedCourseAPI()


    func fetchSelectedCourses(cookie: String, semester: SelectedCourseSemester) async throws -> [SelectedCourse]
    {
        guard let url = URL(string: SchoolDirectAPI.selectedCoursesURL) else
        {
            throw SelectedCourseQueryError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue(SchoolDirectAPI.academicOrigin, forHTTPHeaderField: "Origin")
        request.setValue(SchoolDirectAPI.courseSelectionIndexURL, forHTTPHeaderField: "Referer")
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
