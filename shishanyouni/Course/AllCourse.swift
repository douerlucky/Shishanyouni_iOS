//
//  AllCourse.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/15.
//

import SwiftUI

enum CourseQuerySource: String, QuerySourceOption
{
    case cas = "cas"
    case shishanyouni = "shishanyouni"

    var id: String { rawValue }

    var title: String
    {
        switch self
        {
        case .cas:
            return "CAS"
        case .shishanyouni:
            return "狮山有你"
        }
    }
}

// MARK: - CAS 响应模型

struct AllCourseResponse: Decodable
{
    let items: [CourseInfo]
}

struct CourseClassResponse: Decodable
{
    let kbList: [CourseClassInfo]
}

// MARK: - 狮山有你响应模型

private struct LionRubKeywordResponse: Decodable
{
    let msg: String?
    let code: Int
    let data: [LionRubKeywordItem]?
    let success: Bool?

    var isSuccess: Bool
    {
        success == true || code == 2 || code == 200
    }
}

private struct LionRubKeywordItem: Decodable
{
    let id: Int
    let weekday: String?
    let classTime: String?
    let week: String?
    let cno: String?
    let cname: String
    let tname: String?
    let siteName: String?
    let courseNature: String?
    let className: String?
    let classCode: String
    let courseId: String?
    let schoolYear: String
    let schoolTerm: String
    let type: Int?
    let teacherNum: Int?
}

private struct LionRubDetailResponse: Decodable
{
    let msg: String?
    let code: Int
    let data: LionRubDetailData?
    let success: Bool?

    var isSuccess: Bool
    {
        success == true || code == 2 || code == 200
    }
}

private struct LionRubDetailData: Decodable
{
    let rubList: [LionRubKeywordItem]?
    let tableRes: [LionRubTableItem]?
}

private struct LionRubTableItem: Decodable
{
    let day: Int
    let period: Int
    let length: Int
    let name: String?
    let room: String?
    let teacher: String?
    let week: String?
    let weeks: [Int]?
}

enum AllCourseQueryError: LocalizedError
{
    case invalidURL
    case invalidResponse
    case apiError(String)

    var errorDescription: String?
    {
        switch self
        {
        case .invalidURL:
            return "课程查询地址无效。"
        case .invalidResponse:
            return "课程查询返回了无法识别的响应。"
        case let .apiError(message):
            return message
        }
    }
}

// MARK: - 统一课程模型

struct CourseInfo: Identifiable, Decodable
{
    let row_id: String
    let kch_id: String
    let kch: String
    let kcmc: String
    let kkbmmc: String?
    let kclbmc: String?
    let xnm: String
    let xqm: String
    let kcxzmc: String?
    let classCode: String?
    let teacherName: String?
    let siteName: String?
    let className: String?
    let querySource: CourseQuerySource

    var id: String
    {
        switch querySource
        {
        case .cas:
            return kch_id
        case .shishanyouni:
            return classCode ?? kch_id
        }
    }

    var displayCode: String?
    {
        guard querySource == .cas else { return nil }
        let trimmed = kch.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private enum CodingKeys: String, CodingKey
    {
        case row_id
        case kch_id
        case kch
        case kcmc
        case kkbmmc
        case kclbmc
        case xnm
        case xqm
        case kcxzmc
    }

    init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        row_id = try container.decode(String.self, forKey: .row_id)
        kch_id = try container.decode(String.self, forKey: .kch_id)
        kch = try container.decode(String.self, forKey: .kch)
        kcmc = try container.decode(String.self, forKey: .kcmc)
        kkbmmc = try container.decodeIfPresent(String.self, forKey: .kkbmmc)
        kclbmc = try container.decodeIfPresent(String.self, forKey: .kclbmc)
        xnm = try container.decode(String.self, forKey: .xnm)
        xqm = try container.decode(String.self, forKey: .xqm)
        kcxzmc = try container.decodeIfPresent(String.self, forKey: .kcxzmc)
        classCode = nil
        teacherName = nil
        siteName = nil
        className = nil
        querySource = .cas
    }

    init(
        row_id: String,
        kch_id: String,
        kch: String,
        kcmc: String,
        kkbmmc: String?,
        kclbmc: String?,
        xnm: String,
        xqm: String,
        kcxzmc: String?,
        classCode: String? = nil,
        teacherName: String? = nil,
        siteName: String? = nil,
        className: String? = nil,
        querySource: CourseQuerySource = .cas
    )
    {
        self.row_id = row_id
        self.kch_id = kch_id
        self.kch = kch
        self.kcmc = kcmc
        self.kkbmmc = kkbmmc
        self.kclbmc = kclbmc
        self.xnm = xnm
        self.xqm = xqm
        self.kcxzmc = kcxzmc
        self.classCode = classCode
        self.teacherName = teacherName
        self.siteName = siteName
        self.className = className
        self.querySource = querySource
    }

    fileprivate init(from item: LionRubKeywordItem)
    {
        row_id = String(item.id)
        kch_id = item.courseId ?? item.classCode
        kch = item.cno ?? ""
        kcmc = item.cname
        kkbmmc = nil
        kclbmc = nil
        xnm = item.schoolYear
        xqm = item.schoolTerm
        kcxzmc = item.courseNature
        classCode = item.classCode
        teacherName = item.tname
        siteName = item.siteName
        className = item.className
        querySource = .shishanyouni
    }
}

struct CourseClassInfo: Identifiable, Decodable
{
    let jxb_id: String
    let jxbmc: String
    let xm: String?
    let zcmc: String?
    let cdmc: String?
    let zcd: String?
    let xqjmc: String?
    let jc: String?
    let xkrs: String?
    let jxbzc: String?
    let dayNumber: Int?
    let startPeriod: Int?
    let endPeriod: Int?
    let weekNumbers: [Int]?

    var id: String
    {
        "\(jxb_id)_\(xqjmc ?? "")_\(jc ?? "")_\(cdmc ?? "")_\(zcd ?? "")"
    }

    private enum CodingKeys: String, CodingKey
    {
        case jxb_id
        case jxbmc
        case xm
        case zcmc
        case cdmc
        case zcd
        case xqjmc
        case jc
        case xkrs
        case jxbzc
    }

    init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        jxb_id = try container.decode(String.self, forKey: .jxb_id)
        jxbmc = try container.decode(String.self, forKey: .jxbmc)
        xm = try container.decodeIfPresent(String.self, forKey: .xm)
        zcmc = try container.decodeIfPresent(String.self, forKey: .zcmc)
        cdmc = try container.decodeIfPresent(String.self, forKey: .cdmc)
        zcd = try container.decodeIfPresent(String.self, forKey: .zcd)
        xqjmc = try container.decodeIfPresent(String.self, forKey: .xqjmc)
        jc = try container.decodeIfPresent(String.self, forKey: .jc)
        xkrs = try container.decodeIfPresent(String.self, forKey: .xkrs)
        jxbzc = try container.decodeIfPresent(String.self, forKey: .jxbzc)
        dayNumber = nil
        startPeriod = nil
        endPeriod = nil
        weekNumbers = nil
    }

    fileprivate init(
        jxb_id: String,
        jxbmc: String,
        xm: String?,
        zcmc: String?,
        cdmc: String?,
        zcd: String?,
        xqjmc: String?,
        jc: String?,
        xkrs: String?,
        jxbzc: String?,
        dayNumber: Int? = nil,
        startPeriod: Int? = nil,
        endPeriod: Int? = nil,
        weekNumbers: [Int]? = nil
    )
    {
        self.jxb_id = jxb_id
        self.jxbmc = jxbmc
        self.xm = xm
        self.zcmc = zcmc
        self.cdmc = cdmc
        self.zcd = zcd
        self.xqjmc = xqjmc
        self.jc = jc
        self.xkrs = xkrs
        self.jxbzc = jxbzc
        self.dayNumber = dayNumber
        self.startPeriod = startPeriod
        self.endPeriod = endPeriod
        self.weekNumbers = weekNumbers
    }
}

// MARK: - 查询逻辑

class AllCourseQuery
{
    static let shared = AllCourseQuery()

    private let lionKeywordURL = "https://lion.hzau.edu.cn/app/ios/rub/keyword"
    private let lionDetailURL = "https://lion.hzau.edu.cn/app/ios/rub/getByClassCode"

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

    func fetchLionCourses(keyword: String) async throws -> [CourseInfo]
    {
        var components = URLComponents(string: lionKeywordURL)
        components?.queryItems = [URLQueryItem(name: "keyword", value: keyword)]
        guard let url = components?.url else
        {
            throw AllCourseQueryError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else
        {
            throw AllCourseQueryError.invalidResponse
        }

        try ShishanyouniAPIError.throwIfMFAResponse(data)

        let decoded = try JSONDecoder().decode(LionRubKeywordResponse.self, from: data)
        guard decoded.isSuccess else
        {
            throw AllCourseQueryError.apiError(decoded.msg ?? "狮山有你课程查询失败。")
        }

        return (decoded.data ?? []).map { CourseInfo(from: $0) }
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
        let response = try JSONDecoder().decode(CourseClassResponse.self, from: data)
        return response.kbList
    }

    func fetchLionCourseClasses(classCode: String) async throws -> [CourseClassInfo]
    {
        var components = URLComponents(string: lionDetailURL)
        components?.queryItems = [URLQueryItem(name: "classCode", value: classCode)]
        guard let url = components?.url else
        {
            throw AllCourseQueryError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else
        {
            throw AllCourseQueryError.invalidResponse
        }

        try ShishanyouniAPIError.throwIfMFAResponse(data)

        let decoded = try JSONDecoder().decode(LionRubDetailResponse.self, from: data)
        guard decoded.isSuccess, let payload = decoded.data else
        {
            throw AllCourseQueryError.apiError(decoded.msg ?? "狮山有你课程详情查询失败。")
        }

        let rubList = payload.rubList ?? []
        let tableRes = payload.tableRes ?? []
        let firstRub = rubList.first
        let groupName = firstRub?.className ?? firstRub?.cname ?? "课程安排"
        let groupId = firstRub?.classCode ?? classCode
        let teacher = firstRub?.tname
        let className = firstRub?.className

        if !tableRes.isEmpty
        {
            return tableRes.map
            { item in
                CourseClassInfo(
                    jxb_id: groupId,
                    jxbmc: groupName,
                    xm: item.teacher ?? teacher,
                    zcmc: nil,
                    cdmc: item.room,
                    zcd: item.week,
                    xqjmc: weekdayText(for: item.day),
                    jc: "\(item.period)-\(item.period + item.length - 1)节",
                    xkrs: nil,
                    jxbzc: className,
                    dayNumber: item.day,
                    startPeriod: item.period,
                    endPeriod: item.period + item.length - 1,
                    weekNumbers: item.weeks
                )
            }
        }

        return rubList.map
        { item in
            CourseClassInfo(
                jxb_id: item.classCode,
                jxbmc: item.className ?? item.cname,
                xm: item.tname,
                zcmc: nil,
                cdmc: item.siteName,
                zcd: item.week,
                xqjmc: item.weekday,
                jc: item.classTime,
                xkrs: nil,
                jxbzc: item.className
            )
        }
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

    private func weekdayText(for day: Int) -> String
    {
        switch day
        {
        case 1: return "星期一"
        case 2: return "星期二"
        case 3: return "星期三"
        case 4: return "星期四"
        case 5: return "星期五"
        case 6: return "星期六"
        case 7: return "星期日"
        default: return "未知"
        }
    }
}
