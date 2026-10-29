import Foundation

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
        let data = try await CurriculumAssessmentAPI.fetchTimetable(
            cookie: cookie, year: year, academicTerm: academicTermCode(from: appTerm)
        )

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
    /// 网络请求由 CurriculumAssessmentAPI 负责。
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
