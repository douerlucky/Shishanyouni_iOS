import SwiftUI

// MARK: - 查询逻辑

class CourseAPI
{
    static let shared = CourseAPI()


    /// 获取课程列表
    func fetchAllCourses(cookie: String, xnm: String, xqm: String, kch: String) async throws -> [CourseInfo]
    {
        let urlString = SchoolDirectAPI.courseSearchURL
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
        let (data, _) = try await NetworkService.perform(request: request)
        let response = try JSONDecoder().decode(AllCourseResponse.self, from: data)
        return response.items
    }

    func fetchLionCourses(keyword: String) async throws -> [CourseInfo]
    {
        var components = URLComponents(string: ShishanyouniAPI.courseSearchURL)
        components?.queryItems = [URLQueryItem(name: "keyword", value: keyword)]
        guard let url = components?.url else
        {
            throw AllCourseQueryError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await NetworkService.perform(request: request)
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
        let urlString = SchoolDirectAPI.courseDetailURL
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
        let (data, _) = try await NetworkService.perform(request: request)
        let response = try JSONDecoder().decode(CourseClassResponse.self, from: data)
        return response.kbList
    }

    func fetchLionCourseClasses(classCode: String) async throws -> [CourseClassInfo]
    {
        var components = URLComponents(string: ShishanyouniAPI.courseDetailURL)
        components?.queryItems = [URLQueryItem(name: "classCode", value: classCode)]
        guard let url = components?.url else
        {
            throw AllCourseQueryError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await NetworkService.perform(request: request)
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
        request.setValue(SchoolDirectAPI.academicTimetableReferer, forHTTPHeaderField: "Referer")
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
