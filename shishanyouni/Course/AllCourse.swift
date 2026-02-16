//
//  AllCourse.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/15.
//

import SwiftUI

// 模型定义
struct AllCourseResponse: Decodable
{
    let items: [CourseInfo]
}

struct CourseInfo: Identifiable, Decodable
{
    var id: String { kch_id }
    let row_id: String
    let kch_id: String // 课程ID
    let kch: String // 课程号
    let kcmc: String // 课程名称
    let kkbmmc: String? // 开课部门名称 (例如: 工学院)
    let kclbmc: String? // 课程类别 (例如: 学科专业类课程)
    let xnm: String // 学年
    let xqm: String // 学期
    let kcxzmc: String? // 课程性质 (例如: 必修)
}

// 教学班详情模型
struct CourseClassResponse: Decodable
{
    let kbList: [CourseClassInfo]
}

struct CourseClassInfo: Identifiable, Decodable
{
    var id: String { UUID().uuidString } // 因为同一个 jxb_id 可能对应多个上课时间，所以用 UUID 作为 ID
    let jxb_id: String // 教学班ID
    let jxbmc: String // 教学班名称 (例如: 计算机组成与结构-0001)
    let xm: String? // 教师姓名
    let zcmc: String? // 职称
    let cdmc: String? // 场地名称 (教室)
    let zcd: String? // 周次 (例如: 1-5周)
    let xqjmc: String? // 星期几
    let jc: String? // 节次 (例如: 3-4节)
    let xkrs: String? // 选课人数
    let jxbzc: String? // 教学班组成 (面向班级)
}

// MARK: - 查询逻辑

class AllCourseQuery
{
    static let shared = AllCourseQuery()

    /// 获取课程列表
    func fetchAllCourses(cookie: String, xnm: String, xqm: String, kch: String) async throws -> [CourseInfo]
    {
        let urlString = "http://byjxyt.hzau.edu.cn/kbdy/kckbdy_cxKckbdyList.html?gnmkdm=N214520"
        guard let url = URL(string: urlString) else { throw NSError(domain: "URLError", code: 400) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        setupHeaders(&request, cookie: cookie)

        let timestamp = String(Int(Date().timeIntervalSince1970 * 1000))
        let params: [String: String] = [
            "xnm": xnm, "xqm": xqm, "kch": kch,
            "_search": "false", "nd": timestamp,
            "queryModel.showCount": "50", "queryModel.currentPage": "1",
            "queryModel.sortOrder": "asc", "time": "4",
        ]

        request.httpBody = buildBody(params)
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(AllCourseResponse.self, from: data)
        return response.items
    }

    /// 获取指定课程的教学班列表
    func fetchCourseClasses(cookie: String, xnm: String, xqm: String, kch_id: String) async throws -> [CourseClassInfo]
    {
        let urlString = "http://byjxyt.hzau.edu.cn/kbdy/kckbdy_cxKcKb.html?gnmkdm=N214520"
        guard let url = URL(string: urlString) else { throw NSError(domain: "URLError", code: 400) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        setupHeaders(&request, cookie: cookie)

        let params: [String: String] = [
            "xnm": xnm,
            "xqm": xqm,
            "kch_id": kch_id,
        ]

        request.httpBody = buildBody(params)
        let (data, _) = try await URLSession.shared.data(for: request)

        // 解析数据
        let response = try JSONDecoder().decode(CourseClassResponse.self, from: data)
        return response.kbList
    }

    private func setupHeaders(_ request: inout URLRequest, cookie: String)
    {
        request.setValue("application/x-www-form-urlencoded;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue("http://byjxyt.hzau.edu.cn/kbcx/xskbcx_cxXskbcxIndex.html?gnmkdm=N2151&layout=default", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
    }

    private func buildBody(_ params: [String: String]) -> Data?
    {
        params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
    }
}
