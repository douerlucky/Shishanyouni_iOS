//
//  Curriculum.swift
//  shishanyouni
//
//  课表网络服务（数据结构已迁移至 Data/UserData.swift）
//

import Foundation
import SwiftUI

// MARK: - 课表远程服务

struct CurriculumService
{
    private static let apiURL = "https://lion.hzau.edu.cn/app/ios/timetable"

    struct FetchRequest: Encodable
    {
        let username: String
        let password: String
        let token: String?
        let type: Int = 0
        let year: String
        let term: String
    }

    static func fetchCourses(
        username: String,
        password: String,
        token: String = "",
        year: String,
        term: String
    ) async throws -> (courses: [Course], startDate: Date?)
    {
        guard let url = URL(string: apiURL) else { throw CurriculumError.invalidURL }

        let body = FetchRequest(username: username, password: password,
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

// MARK: - 课程考核方式（考试 / 考查）

/// 教务「我的课表（学生）」接口中的单条课次。
///
/// 这个接口与狮山有你自己的课表接口不同：它带有 `khfsmc`，因此只用来
/// 补充考核方式，不参与课程时间、地点等主数据的解析。
private struct CurriculumAssessmentItem: Decodable
{
    let courseName: String?
    let teachingClassName: String?
    let assessmentMethod: String?

    private enum CodingKeys: String, CodingKey
    {
        case courseName = "kcmc"
        case teachingClassName = "jxbmc"
        case assessmentMethod = "khfsmc"
    }
}

private struct CurriculumAssessmentResponse: Decodable
{
    let kbList: [CurriculumAssessmentItem]?
}

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
    private static let endpoint = "http://byjxyt.hzau.edu.cn/kbcx/xskbcxMobile_cxXsKb.html"
    private static let referer = "http://byjxyt.hzau.edu.cn/kbcx/xskbcxMobile_cxTimeTableIndex.html?gnmkdm=N2190&layout=default"

    /// `CurriculumSettingView` 使用狮山接口的学期码 1/2；教务课表接口使用 3/12。
    static func academicTermCode(from appTerm: String) -> String
    {
        appTerm == "2" ? "12" : "3"
    }

    /// 返回“课程名称 -> 考核方式”的映射，只保留考试/考查。
    /// “未安排”通常是实验或上机附加教学班，不在课程卡片上显示。
    static func fetchAssessmentMethods(
        cookie: String,
        year: String,
        appTerm: String
    ) async throws -> [String: String]
    {
        guard let url = URL(string: endpoint) else
        {
            throw CurriculumAssessmentError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148", forHTTPHeaderField: "User-Agent")
        request.setValue(referer, forHTTPHeaderField: "Referer")
        request.setValue("http://byjxyt.hzau.edu.cn", forHTTPHeaderField: "Origin")
        request.setValue(cookie, forHTTPHeaderField: "Cookie")

        // 关键：不传 `zs`，这样教务系统会返回整学期，而不是只返回某一周。
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
    /// 单独抽出来是为了让测试可以使用脱敏样本验证业务规则，而不需要登录教务系统。
    /// 线上请求仍由 `fetchAssessmentMethods` 负责，调用方不应直接构造 Cookie。
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

//Color Hex 互转自定义课程颜色使用

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Color
{
    init?(hex: String)
    {
        let hex = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        guard hex.count == 6, let value = UInt64(hex, radix: 16) else { return nil }
        self.init(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }

    func toHex() -> String?
    {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        #elseif canImport(AppKit)
        let uiColor = NSColor(self)
        #else
        return nil
        #endif
        guard let components = uiColor.cgColor.components, components.count >= 3 else { return nil }
        return String(format: "#%02X%02X%02X", Int(components[0]*255), Int(components[1]*255), Int(components[2]*255))
    }
}
