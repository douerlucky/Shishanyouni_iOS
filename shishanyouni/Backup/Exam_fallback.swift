////
////  Exam.swift
////  shishanyouni
////
////  Originally by douer_lucky on 2026/2/13.
////  Refactored: replaced old byjxyt cookie-based API with
////  the new lion.hzau.edu.cn iOS exam endpoint.
////
//
//import Foundation
//
//// MARK: - API 响应结构体
//
///// POST https://lion.hzau.edu.cn/app/ios/exam 顶层响应
//struct ExamResponse: Decodable {
//    let msg: String?
//    let code: Int
//    let data: [ExamItem]?
//
//    var isSuccess: Bool { code == 200 || code == 2 }
//}
//
///// 单条考试数据（字段名与接口文档完全一致）
//struct ExamItem: Decodable {
//    let xm: String?    // 姓名
//    let xh: String?    // 学号
//    let kcmc: String   // 课程名称
//    let ksmc: String   // 考试名称（如：期末考试）
//    let kssj: String   // 考试时间（如：2026-01-19(09:00-11:00)）
//    let cdmc: String?  // 考试地点
//    let bj: String?    // 班级
//    let zwh: String?   // 座位号
//}
//
//struct Exam: Identifiable {
//    let id: String      // kcmc + kssj 拼接，保证唯一
//    let kcmc: String    // 课程名称
//    let ksmc: String    // 考试名称
//    let kssj: String    // 原始时间字符串
//    let cdmc: String?   // 考试地点
//    let zwh: String?    // 座位号
//    let bj: String?     // 班级
//
//    /// 日期部分，如 "2026-01-19"
//    var examDate: String {
//        kssj.components(separatedBy: "(").first ?? kssj
//    }
//
//    /// 时间部分，如 "09:00-11:00"
//    var examTime: String {
//        guard let raw = kssj.components(separatedBy: "(").last else { return "" }
//        return raw.replacingOccurrences(of: ")", with: "")
//    }
//
//    init(from item: ExamItem) {
//        self.id    = "\(item.kcmc)_\(item.kssj)"
//        self.kcmc  = item.kcmc
//        self.ksmc  = item.ksmc
//        self.kssj  = item.kssj
//        self.cdmc  = item.cdmc.flatMap { $0.isEmpty ? nil : $0 }
//        self.zwh   = item.zwh.flatMap  { $0.isEmpty ? nil : $0 }
//        self.bj    = item.bj.flatMap   { $0.isEmpty ? nil : $0 }
//    }
//}
//
//// MARK: - 考试查询服务
//
//struct ExamService {
//
//    private static let apiURL = "https://lion.hzau.edu.cn/app/ios/exam"
//
//    struct FetchRequest: Encodable {
//        let yhm: String     // 学号
//        let mm: String      // 明文密码
//        let xnm: String     // 学年起始年份，如 "2025"
//        let xqm: String     // 学期："1" = 秋季，"2" = 春季
//        let type: Int = 1   // 账户类型，固定传 1（信息门户）
//    }
//
//    static func fetchExams(
//        username: String,
//        password: String,
//        year: String,
//        term: String
//    ) async throws -> [Exam] {
//
//        var components = URLComponents(string: apiURL)!
//        components.queryItems = [
//            URLQueryItem(name: "yhm",  value: username),
//            URLQueryItem(name: "mm",   value: password),
//            URLQueryItem(name: "xnm",  value: year),
//            URLQueryItem(name: "xqm",  value: term),
//            URLQueryItem(name: "type", value: "1"),
//        ]
//
//        guard let url = components.url else {
//            throw ExamError.invalidURL
//        }
//
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//
//        print("开始拉取考试信息… 学年:\(year) 学期:\(term)")
//        print("请求URL: \(url)")   // 加这行确认参数有没有拼上
//
//        let (data, response) = try await URLSession.shared.data(for: request)
//
//        guard let http = response as? HTTPURLResponse else {
//            throw ExamError.invalidResponse
//        }
//        guard http.statusCode == 200 else {
//            throw ExamError.httpError(http.statusCode)
//        }
//
//        if let raw = String(data: data, encoding: .utf8) {
//            print("📥 原始响应（前500字）：\(raw.prefix(500))")
//        }
//
//        let decoded = try JSONDecoder().decode(ExamResponse.self, from: data)
//
//        guard decoded.isSuccess else {
//            throw ExamError.apiError(decoded.msg ?? "未知错误，code=\(decoded.code)")
//        }
//
//        let items = (decoded.data ?? []).map { Exam(from: $0) }
//        return items.sorted { $0.kssj < $1.kssj }
//    }
//}
//
//// MARK: - 错误枚举
//
//enum ExamError: LocalizedError {
//    case invalidURL
//    case invalidResponse
//    case httpError(Int)
//    case apiError(String)
//    case jsonDecodingFailed(Error)
//
//    var errorDescription: String? {
//        switch self {
//        case .invalidURL:                  return "接口地址无效"
//        case .invalidResponse:             return "无效的服务器响应"
//        case .httpError(let code):         return "HTTP 错误：\(code)"
//        case .apiError(let msg):           return "服务端错误：\(msg)"
//        case .jsonDecodingFailed(let err): return "数据解析失败：\(err.localizedDescription)"
//        }
//    }
//}
