//
//  Schedule.swift
//  shishanyouni
//
//  Originally by douer_lucky on 2026/2/10.
//  Refactored: clean data model matching lion.hzau.edu.cn iOS API fields directly.
//

import Foundation
import SwiftUI

struct TimetableResponse: Decodable
{
    let msg: String?
    let code: Int
    let data: TimetableData?

    /// code == 200 或实测成功值 2 均视为成功
    var isSuccess: Bool { code == 200 || code == 2 }
}

struct TimetableData: Decodable
{
    let timetableModels: [TimetableModel]
    let others: [String]?
    /// 开学日期，格式 "yyyy-MM-dd"，如 "2026-03-02"
    let startDate: String?
    let loadTime: Int64?
}

// 单条课程
struct TimetableModel: Decodable
{
    let name: String // 课程名
    let room: String? // 教室
    let teacher: String? // 教师
    let weekList: [Int] // 第几周到第几周上课
    let start: Int // 开始上课节次
    let step: Int // 上课的节数
    let day: Int // 周几上
    let term: String?
    let colorRandom: Int // 随机数 课程颜色
    let weeks: String?
    let time: String?
}

// 课程数据模型
struct Course: Identifiable, Codable
{
    let id: String // 唯一标识服务端课程 = "term_day_start_name"，手动课程 = "manual_UUID"
    let name: String // 课程名称
    let day: Int // 周几（1=周一 … 7=周日）
    let start: Int // 开始节次
    let step: Int // 连续上课节数
    let room: String? // 教室
    let teacher: String? // 教师
    let weekList: [Int] // 上课的具体周次列表，如 [1,2,3,4,5,6,7,8,9,12]
    let weeks: String? // 上课周次文本描述，如 "1-9周,12周"（仅用于显示，逻辑判断用 weekList）
    let term: String? // 学期标识，如 "2025-2"
    var colorRandom: Int // 颜色索引（来自服务端 colorRandom，手动课程随机分配）
    var customColorHex: String? // 用户自定义颜色（十六进制，如 "#FF6B6B"），nil = 使用 colorRandom
    var isManual: Bool // true = 用户手动添加，false = 服务端导入

    var endPeriod: Int { start + step - 1 } // 计算结束节次
    var parsedWeeks: Set<Int> { Set(weekList) } // 本课程上课的周次集合（供 ScheduleView 过滤使用）
}

extension Course
{
    init(from model: TimetableModel)
    {
        let uniqueID = "\(model.term ?? "unknown")_day\(model.day)_s\(model.start)_\(model.name)"

        // 周次文本：优先用 weeks，其次 time，最后从 weekList 拼回
        let weeksText: String? = {
            if let w = model.weeks, !w.isEmpty { return w }
            if let t = model.time, !t.isEmpty { return t }
            if model.weekList.isEmpty { return nil }
            return model.weekList.sorted().map { "\($0)" }.joined(separator: ",") + "周"
        }()

        self.init(
            id: uniqueID,
            name: model.name,
            day: model.day,
            start: model.start,
            step: model.step,
            room: model.room.flatMap { $0.isEmpty ? nil : $0 },
            teacher: model.teacher.flatMap { $0.isEmpty ? nil : $0 },
            weekList: model.weekList,
            weeks: weeksText,
            term: model.term,
            colorRandom: model.colorRandom,
            customColorHex: nil,
            isManual: false
        )
    }
}

// MARK: - 手动课程工厂

extension Course
{
    static func createManualCourse(
        name: String,
        weekday: Int,
        startPeriod: Int,
        endPeriod: Int,
        weeks: Set<Int>,
        location: String? = nil,
        teacher: String? = nil,
        customColorHex: String? = nil
    ) -> Course
    {
        let uid = "manual_\(UUID().uuidString)"
        let sortedWeeks = weeks.sorted()
        let weeksText = sortedWeeks.map { "\($0)" }.joined(separator: ",") + "周"

        return Course(
            id: uid,
            name: name,
            day: weekday,
            start: startPeriod,
            step: endPeriod - startPeriod + 1,
            room: location,
            teacher: teacher,
            weekList: sortedWeeks,
            weeks: weeksText,
            term: nil,
            colorRandom: Int.random(in: 0 ... 31),
            customColorHex: customColorHex,
            isManual: true
        )
    }
}

struct ScheduleService
{
    private static let apiURL = "https://lion.hzau.edu.cn/app/ios/timetable"

    struct FetchRequest: Encodable
    {
        let username: String
        let password: String
        let type: Int = 0
        /// 学年起始年份，如 "2025" 表示 2025-2026 学年
        let year: String
        /// "1" = 秋季学期，"2" = 春季学期
        let term: String
    }

    /// 拉取课表，返回 `[Course]` 与开学日期（可能为 nil）
    static func fetchCourses(
        username: String,
        password: String,
        year: String,
        term: String
    ) async throws -> (courses: [Course], startDate: Date?)
    {
        guard let url = URL(string: apiURL)
        else
        {
            throw ScheduleError.invalidURL
        }

        let body = FetchRequest(username: username, password: password,
                                year: year, term: term)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        print("开始拉取课表… 学年:\(year) 学期:\(term)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse
        else
        {
            throw ScheduleError.invalidResponse
        }
        guard http.statusCode == 200
        else
        {
            throw ScheduleError.httpError(http.statusCode)
        }

        if let raw = String(data: data, encoding: .utf8)
        {
            print("📥 原始响应（前500字）：\(raw.prefix(500))")
        }

        let decoded: TimetableResponse
        do
        {
            decoded = try JSONDecoder().decode(TimetableResponse.self, from: data)
        }
        catch
        {
            throw ScheduleError.jsonDecodingFailed(error)
        }

        guard decoded.isSuccess, let payload = decoded.data
        else
        {
            throw ScheduleError.apiError(decoded.msg ?? "未知错误，code=\(decoded.code)")
        }

        // 同一课程名使用相同颜色（沿用服务端 colorRandom）
        var colorMap: [String: Int] = [:]
        let courses: [Course] = payload.timetableModels.map
        { model in
            if colorMap[model.name] == nil
            {
                colorMap[model.name] = model.colorRandom
            }
            var c = Course(from: model)
            c.colorRandom = colorMap[model.name]!
            return c
        }

        // 解析开学日期
        let startDate: Date? = payload.startDate.flatMap
        { dateStr in
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            fmt.locale = Locale(identifier: "en_US_POSIX")
            return fmt.date(from: dateStr)
        }

        print("课表拉取成功，共 \(courses.count) 条，开学日期：\(payload.startDate ?? "未返回")")
        return (courses, startDate)
    }
}

// MARK: - 错误枚举

enum ScheduleError: LocalizedError
{
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case jsonDecodingFailed(Error)

    var errorDescription: String?
    {
        switch self
        {
        case .invalidURL: return "接口地址无效"
        case .invalidResponse: return "无效的服务器响应"
        case let .httpError(code): return "HTTP 错误：\(code)"
        case let .apiError(msg): return "服务端错误：\(msg)"
        case let .jsonDecodingFailed(err): return "数据解析失败：\(err.localizedDescription)"
        }
    }
}

//Color Hex 互转自定义课程颜色使用

extension Color
{
    // 从十六进制字符串构造颜色，支持 "#RRGGBB" 或 "RRGGBB"
    init?(hex: String)
    {
        let hex = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        guard hex.count == 6, let value = UInt64(hex, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    // 转为 "#RRGGBB" 字符串
    func toHex() -> String?
    {
        guard let components = UIColor(self).cgColor.components,
              components.count >= 3 else { return nil }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
