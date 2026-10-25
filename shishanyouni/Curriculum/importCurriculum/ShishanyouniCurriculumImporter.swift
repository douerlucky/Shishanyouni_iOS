//
//  ShishanyouniCurriculumImporter.swift
//  shishanyouni
//
//  课表网络服务；接口模型位于 API/Models/CurriculumAPIModels.swift
//

import Foundation

// MARK: - 课表远程服务

enum ShishanyouniCurriculumImporter
{

    static func fetchCourses(
        username: String,
        password: String,
        token: String = "",
        year: String,
        term: String
    ) async throws -> (courses: [Course], startDate: Date?)
    {
        guard let url = URL(string: ShishanyouniAPI.timetableURL) else { throw CurriculumError.invalidURL }

        let body = TimetableRequest(username: username, password: password,
                                token: token.isEmpty ? nil : token,
                                year: year, term: term)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        print("开始拉取课表… 学年:\(year) 学期:\(term)")

        let (data, response) = try await NetworkService.perform(request: request)

        guard let http = response as? HTTPURLResponse else { throw CurriculumError.invalidResponse }
        guard http.statusCode == 200 else { throw CurriculumError.httpError(http.statusCode) }

        if let raw = String(data: data, encoding: .utf8) { print("📥 原始响应（前500字）：\(raw.prefix(500))") }

        try ShishanyouniAPIError.throwIfMFAResponse(data)

        let decoded: TimetableResponse
        do { decoded = try JSONDecoder().decode(TimetableResponse.self, from: data) }
        catch { throw CurriculumError.jsonDecodingFailed(error) }

        guard decoded.isSuccess, let payload = decoded.data else {
            throw ShishanyouniAPIError.apiError(code: decoded.code, message: decoded.msg ?? "未知错误")
        }

        var colorMap: [String: Int] = [:]
        let courses: [Course] = payload.timetableModels.map { model in
            if colorMap[model.name] == nil { colorMap[model.name] = model.colorRandom }
            var c = Course(from: model)
            c.colorRandom = colorMap[model.name]!
            return c
        }

        let startDate: Date? = payload.startDate.flatMap { dateStr in
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            fmt.locale = Locale(identifier: "en_US_POSIX")
            return fmt.date(from: dateStr)
        }

        print("课表拉取成功，共 \(courses.count) 条，开学日期：\(payload.startDate ?? "未返回")")
        return (courses, startDate)
    }
}
