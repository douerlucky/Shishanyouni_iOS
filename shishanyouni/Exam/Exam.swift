//
//  Exam.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/13.
//

import Foundation

enum ExamQuerySource: String, CaseIterable, Identifiable {
    case cas = "cas"
    case shishanyouni = "shishanyouni"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cas: return "CAS"
        case .shishanyouni: return "狮山有你"
        }
    }
}

struct ExamResponse: Decodable
{
    let items: [Exam]
}

private struct LionExamResponse: Decodable {
    let msg: String?
    let code: Int
    let data: [LionExamItem]?
    let success: Bool?

    var isSuccess: Bool {
        success == true || code == 2 || code == 200
    }
}

private struct LionExamItem: Decodable {
    let xm: String?
    let xh: String?
    let kcmc: String
    let ksmc: String
    let kssj: String
    let cdmc: String?
    let bj: String?
}

enum ExamQueryError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "考试查询地址无效。"
        case .invalidResponse:
            return "考试查询返回了无法识别的响应。"
        case let .apiError(message):
            return message
        }
    }
}

struct Exam: Identifiable, Decodable
{
    var id: String {
        if let rowID = rowID {
            return String(rowID)
        }
        return "\(kcmc)_\(ksmc)_\(kssj)"
    }

    private let rowID: Int?
    let kcmc: String
    let ksmc: String
    let kssj: String
    let cdmc: String?
    let zwh: String?
    let xf: String?
    let jxbmc: String?
    let bj: String?
    let querySource: ExamQuerySource

    private enum CodingKeys: String, CodingKey {
        case rowID = "row_id"
        case kcmc
        case ksmc
        case kssj
        case cdmc
        case zwh
        case xf
        case jxbmc
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rowID = try container.decodeIfPresent(Int.self, forKey: .rowID)
        kcmc = try container.decode(String.self, forKey: .kcmc)
        ksmc = try container.decode(String.self, forKey: .ksmc)
        kssj = try container.decode(String.self, forKey: .kssj)
        cdmc = try container.decodeIfPresent(String.self, forKey: .cdmc)
        zwh = try container.decodeIfPresent(String.self, forKey: .zwh)
        xf = try container.decodeIfPresent(String.self, forKey: .xf)
        jxbmc = try container.decodeIfPresent(String.self, forKey: .jxbmc)
        bj = nil
        querySource = .cas
    }

    fileprivate init(from item: LionExamItem) {
        rowID = nil
        kcmc = item.kcmc
        ksmc = item.ksmc
        kssj = item.kssj
        cdmc = item.cdmc.flatMap { $0.isEmpty ? nil : $0 }
        zwh = nil
        xf = nil
        jxbmc = nil
        bj = item.bj.flatMap { $0.isEmpty ? nil : $0 }
        querySource = .shishanyouni
    }

    var examDate: String
    {
        kssj.components(separatedBy: "(").first ?? kssj
    }

    var examTime: String
    {
        if let time = kssj.components(separatedBy: "(").last
        {
            return time.replacingOccurrences(of: ")", with: "")
        }
        return ""
    }

    var seatDisplayText: String {
        if let zwh, !zwh.isEmpty {
            return "座位: \(zwh)"
        }

        switch querySource {
        case .cas:
            return "不支持座位号"
        case .shishanyouni:
            return "不支持座位号"
        }
    }
}

class ExamQuery
{
    static let shared = ExamQuery()
    private let lionURL = "https://lion.hzau.edu.cn/app/ios/exam"

    func fetchExams(cookie: String, xnm: String, xqm: String) async throws -> [Exam]
    {
        let urlString = "http://byjxyt.hzau.edu.cn/kwgl/kscx_cxXsksxxIndex.html?doType=query&gnmkdm=N358105"
        guard let url = URL(string: urlString) else { throw NSError(domain: "URLError", code: 400) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue("http://byjxyt.hzau.edu.cn/kbcx/xskbcx_cxXskbcxIndex.html?gnmkdm=N2151&layout=default", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue(cookie, forHTTPHeaderField: "Cookie")

        let params = [
            "xnm": xnm,
            "xqm": xqm,
            "queryModel.showCount": "100",
            "queryModel.currentPage": "1",
        ]

        request.httpBody = params
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(ExamResponse.self, from: data)
        return response.items
    }

    func fetchExamsFromShishanyouni(username: String, encryptedPassword: String, xnm: String, xqm: String) async throws -> [Exam] {
        guard let url = URL(string: lionURL) else {
            throw ExamQueryError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "xnm": xnm,
            "xqm": xqm,
            "yhm": username,
            "mm": encryptedPassword,
            "type": 1,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw ExamQueryError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(LionExamResponse.self, from: data)
        guard decoded.isSuccess else {
            throw ExamQueryError.apiError(decoded.msg ?? "狮山有你考试查询失败。")
        }

        return (decoded.data ?? [])
            .map { Exam(from: $0) }
            .sorted { $0.kssj < $1.kssj }
    }
}
