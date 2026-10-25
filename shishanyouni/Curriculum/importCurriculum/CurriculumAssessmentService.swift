import Foundation

// MARK: - 课程考核方式（考试 / 考查）

// 考核方式接口模型位于 API/Models/CurriculumAPIModels.swift。

enum CurriculumAssessmentError: LocalizedError
{
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingFailed(Error)

    var errorDescription: String?
    {
        switch self
        {
        case .invalidURL:
            return "考核方式查询地址无效。"
        case .invalidResponse:
            return "考核方式查询返回了无法识别的响应。"
        case let .httpError(code):
            return "考核方式查询失败（状态码 \(code)）。"
        case let .decodingFailed(error):
            return "考核方式数据解析失败：\(error.localizedDescription)"
        }
    }
}

/// 通过当前账号的教务 Cookie 查询整学期考核方式。
enum CurriculumAssessmentService
{

    /// 导入选择器使用统一学期码 1/2；教务课表接口使用 3/12。
    static func academicTermCode(from appTerm: String) -> String
    {
        AcademicCurriculumImporter.academicTermCode(from: appTerm)
    }

    /// 返回“课程名称 -> 考核方式”的映射，只保留考试/考查。
    /// “未安排”通常是实验或上机附加教学班，不在课程卡片上显示。
    static func fetchAssessmentMethods(
        cookie: String,
        year: String,
        appTerm: String
    ) async throws -> [String: String]
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
        let encodedTerm = formEncode(academicTermCode(from: appTerm))
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

        do
        {
            let result = try parseAssessmentMethods(from: data)
            print("✅ 考核方式查询成功，共匹配 \(result.count) 门课程")
            return result
        }
        catch let error as CurriculumAssessmentError
        {
            // 登录态失效时服务端常返回 HTML 登录页；不要把整页内容打进日志。
            print("⚠️ 考核方式响应不是可解析的课表 JSON（可能是教务 Cookie 失效）")
            throw error
        }
        catch
        {
            print("⚠️ 考核方式响应解析失败（可能是教务 Cookie 失效）")
            throw CurriculumAssessmentError.decodingFailed(error)
        }
    }

    /// 解析教务接口原始 JSON。
    ///
    /// 单独抽出解析，便于使用脱敏样本测试，不需要登录本研教学一体化平台。
    /// 线上请求仍由 `fetchAssessmentMethods` 负责。
    static func parseAssessmentMethods(from data: Data) throws -> [String: String]
    {
        let decoded: CurriculumAssessmentResponse
        do
        {
            decoded = try JSONDecoder().decode(CurriculumAssessmentResponse.self, from: data)
        }
        catch
        {
            throw CurriculumAssessmentError.decodingFailed(error)
        }

        var candidates: [String: [(method: String, score: Int)]] = [:]
        for item in decoded.kbList ?? []
        {
            guard let courseName = normalizedCourseName(item.courseName),
                  let method = normalizedAssessmentMethod(item.assessmentMethod)
            else
            {
                continue
            }

            // 纯数字教学班（如 -0001）通常是理论班，优先于 -0001A/-0001C 实验班。
            let teachingClass = item.teachingClassName ?? ""
            let suffix = teachingClass.split(separator: "-").last.map(String.init) ?? ""
            let theoryClassScore = suffix.allSatisfy(\.isNumber) ? 10 : 0
            candidates[courseName, default: []].append((method, theoryClassScore))
        }

        var result: [String: String] = [:]
        for (courseName, values) in candidates
        {
            // 先取理论班；同一课程多个理论班且结果一致时自然保持一致。
            result[courseName] = values
                .sorted { $0.score > $1.score }
                .first?.method
        }
        return result
    }

    private static func formEncode(_ value: String) -> String
    {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private static func normalizedCourseName(_ value: String?) -> String?
    {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private static func normalizedAssessmentMethod(_ value: String?) -> String?
    {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.contains("考试") { return "考试" }
        if normalized.contains("考查") { return "考查" }
        return nil
    }
}
