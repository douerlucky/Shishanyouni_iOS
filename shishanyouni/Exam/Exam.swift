//
//  Exam.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/13.
//

import Foundation

struct ExamResponse: Decodable
{
    let items: [Exam]
}

struct Exam: Identifiable, Decodable
{
    var id: Int { row_id }
    let row_id: Int
    let kcmc: String // 课程名称
    let ksmc: String // 考试名称 (如：期末考试)
    let kssj: String // 考试时间 (2026-01-19(09:00-11:00))
    let cdmc: String? // 场地名称 (三教C305)
    let zwh: String? // 座位号
    let xf: String? // 学分
    let jxbmc: String? // 教学班名称

    // 拆分日期和时间
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
}

class ExamQuery
{
    static let shared = ExamQuery()

    func fetchExams(cookie: String,xnm: String, xqm: String) async throws -> [Exam]
    {


        // 构建请求
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
        
        // 3. 构建参数
        let params = [
            "xnm": xnm, // 学年 (如 2025)
            "xqm": xqm, // 学期 (1 或 3)
            "queryModel.showCount": "100",
            "queryModel.currentPage": "1",
        ]

        request.httpBody = params
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        // 4. 发送请求
        let (data, _) = try await URLSession.shared.data(for: request)

        // 调试用：打印原始数据
        // if let json = String(data: data, encoding: .utf8) { print("Exam JSON: \(json)") }

        let response = try JSONDecoder().decode(ExamResponse.self, from: data)
        return response.items
    }
}
