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
