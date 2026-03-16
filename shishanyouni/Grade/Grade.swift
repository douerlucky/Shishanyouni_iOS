//
//  Grade.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/6.
//

import Foundation


struct LionGradeResponse: Decodable
{
    let msg: String?
    let code: Int?
    let data: [Grade]?
    let timestamp: Int64?
    let success: Bool?
    let fail: Bool?
}

struct Grade: Identifiable, Decodable
{
    let jxb_id: String
    var id: String { jxb_id }

    let kcmc: String       // 课程名称
    let kcxzmc: String?    // 课程性质（必修 / 选修）
    let xf: String         // 学分
    let cj: String         // 成绩
    let jd: String         // 绩点
    let khfsmc: String?    // 考核方式（考试 / 考查）
    let kcgsmc: String?    // 课程归属名称
    let xm: String?        // 学生姓名
    let bj: String?        // 班级
    let kch: String?       // 课程号
    let jsxm: String?      // 教师姓名
    let kkbmmc: String?    // 开课部门
    let xnmmc: String?     // 学年名称（如 2025-2026）
    let xqmmc: String?     // 学期名称
    let detail: String?
    let bfzcj: String?     // 百分制成绩
}

class GradeService
{
    private let baseURL = "https://lion.hzau.edu.cn//app/ios/score"

    /// xnm: 学年开始年份（如 "2025" 代表 2025-2026 学年）
    /// xqm: 学期（"1" 第一学期，"2" 第二学期）
    func fetchGrades(username: String, password: String, xnm: String, xqm: String) async throws -> [Grade]
    {
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "xnm",  value: xnm),
            URLQueryItem(name: "xqm",  value: xqm),
            URLQueryItem(name: "yhm",  value: username),
            URLQueryItem(name: "mm",   value: password),
            URLQueryItem(name: "type", value: "1"),
        ]

        guard let url = components.url else
        {
            throw NSError(domain: "GradeService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "URL 构建失败"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else
        {
            throw NSError(domain: "GradeService", code: 500,
                          userInfo: [NSLocalizedDescriptionKey: "网络请求失败"])
        }

        let decoded = try JSONDecoder().decode(LionGradeResponse.self, from: data)

        guard decoded.success == true else
        {
            let msg = decoded.msg ?? "服务器返回未知错误"
            throw NSError(domain: "GradeService", code: decoded.code ?? -1,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }

        return decoded.data ?? []
    }
}
