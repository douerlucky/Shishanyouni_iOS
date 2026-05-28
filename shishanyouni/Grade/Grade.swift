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

struct Grade: Identifiable, Codable
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
    private let baseURL = "https://lion.hzau.edu.cn/app/ios/score"

    /// xnm: 学年开始年份（如 "2025" 代表 2025-2026 学年）
    /// xqm: 学期（"1" 第一学期，"2" 第二学期）
    func fetchGrades(username: String, password: String, token: String = "", xnm: String, xqm: String) async throws -> [Grade]
    {
        print("收到的rsa密钥:", password)

        guard let url = URL(string: baseURL) else
        {
            throw NSError(domain: "GradeService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "URL 构建失败"])
        }

        // 构建 JSON body
        var body: [String: Any] = [
            "xnm":  xnm,
            "xqm":  xqm,
            "yhm":  username,
            "mm":   password,
            "type": 1
        ]
        if !token.isEmpty
        {
            body["token"] = token
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else
        {
            throw NSError(domain: "GradeService", code: 500,
                          userInfo: [NSLocalizedDescriptionKey: "网络请求失败"])
        }

        try ShishanyouniAPIError.throwIfMFAResponse(data)

        let decoded = try JSONDecoder().decode(LionGradeResponse.self, from: data)

        guard decoded.success == true || decoded.code == 2 || decoded.code == 200 else
        {
            let msg = decoded.msg ?? "服务器返回未知错误"
            throw ShishanyouniAPIError.apiError(code: decoded.code, message: msg)
        }

        return decoded.data ?? []
    }
}
