//
//  Course.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/10.
//

import Foundation

// MARK: - 响应结构体

struct ScheduleResponse: Decodable
{
    let kbList: [Course]
}

// MARK: - 课程结构体

struct Course: Identifiable, Decodable, Encodable
{
    let jxb_id: String // 教学班ID（唯一标识）
    let kch_id: String // 课程ID
    let kcmc: String // 课程名称
    let xqj: String // 星期几（1-7）
    let jcs: String // 节次（如"5-8"）
    let cdmc: String? // 教室名称
    let xm: String? // 教师姓名
    let zcmc: String? // 教师职称
    let jxbzc: String? // 上课班级（分号分隔）
    let zcd: String? // 周次（如"4-5周,7-8周"）
    let xqjmc: String? // 星期几中文（如"星期一"）
    
    var colorIndex: Int? = 0 //用于固定保存颜色的索引

    // 使用教学班ID作为唯一标识
    var id: String
    {
        jxb_id
    }

    // 计算属性：格式化的节次显示
    var formattedJcs: String
    {
        "第\(jcs)节"
    }

    // 计算属性：班级列表
    var classList: [String]
    {
        jxbzc?.components(separatedBy: ";") ?? []
    }

    var parsedWeeks: Set<Int>
    {
        guard let zcd = zcd else { return Set() }

        var result = Set<Int>()

        // 去掉"周"，按逗号分割成各个部分
        let segments = zcd.replacingOccurrences(of: "周", with: "").components(separatedBy: ",")

        for segment in segments
        {
            let trimmed = segment.trimmingCharacters(in: .whitespaces)

            // 检查是否包含单双周标记
            let isSingleWeek = trimmed.contains("(单)") || trimmed.contains("（单）")
            let isDoubleWeek = trimmed.contains("(双)") || trimmed.contains("（双）")

            // 移除单双周标记，提取数字部分
            let cleanSegment = trimmed
                .replacingOccurrences(of: "(单)", with: "")
                .replacingOccurrences(of: "（单）", with: "")
                .replacingOccurrences(of: "(双)", with: "")
                .replacingOccurrences(of: "（双）", with: "")
                .trimmingCharacters(in: .whitespaces)

            if cleanSegment.contains("-")
            {
                // 处理范围格式 "8-9"、"13-17(单)"、"6-10(双)" 等
                let parts = cleanSegment.components(separatedBy: "-")
                if parts.count == 2,
                   let start = Int(parts[0].trimmingCharacters(in: .whitespaces)),
                   let end = Int(parts[1].trimmingCharacters(in: .whitespaces))
                {
                    for w in start ... end
                    {
                        // 如果有单周标记，只添加奇数周
                        if isSingleWeek && w % 2 == 1
                        {
                            result.insert(w)
                        }
                        // 如果有双周标记，只添加偶数周
                        else if isDoubleWeek && w % 2 == 0
                        {
                            result.insert(w)
                        }
                        // 没有单双周标记，添加所有周
                        else if !isSingleWeek && !isDoubleWeek
                        {
                            result.insert(w)
                        }
                    }
                }
            }
            else if let singleWeek = Int(cleanSegment)
            {
                // 处理单周格式 "5"、"12"、"18" 等
                // 单周或没有标记都直接添加
                result.insert(singleWeek)
            }
        }
        return result
    }
}

// MARK: - 课表查询类

class ScheduleQuery: NSObject, URLSessionTaskDelegate
{
    private let step1And2URL = "https://cas-paas.hzau.edu.cn/cas/login?service=http%3A%2F%2Fbyjxyt.hzau.edu.cn%2Fswlogin"
    private let courseQueryURL = "http://byjxyt.hzau.edu.cn/kbcx/xskbcx_cxXsKb.html?gnmkdm=N2151"

    // 手动存储 cookies
    private var cookieJar: [String: String] = [:]

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    // MARK: - 禁用自动重定向

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest: URLRequest, completionHandler: @escaping (URLRequest?) -> Void)
    {
        completionHandler(nil)
    }

    // MARK: - Cookie 管理

    private func extractCookies(from response: HTTPURLResponse)
    {
        if let setCookies = response.allHeaderFields["Set-Cookie"] as? String
        {
            let cookies = setCookies.components(separatedBy: ",")
            for cookie in cookies
            {
                if let nameValuePair = cookie.components(separatedBy: ";").first
                {
                    let parts = nameValuePair.trimmingCharacters(in: .whitespaces).components(separatedBy: "=")
                    if parts.count == 2
                    {
                        cookieJar[parts[0]] = parts[1]
                        print("保存Cookie: \(parts[0])=\(parts[1].prefix(20))...")
                    }
                }
            }
        }
    }

    private func getCookieHeader() -> String
    {
        return cookieJar.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
    }

    // MARK: - 登录获取Cookie

    func loginAndGetCookie(username: String, rsaPassword: String) async throws -> String
    {
        // Step 1: GET 获取 Execution
        print("🔐 Step 1: 获取登录页面")
        var request1 = URLRequest(url: URL(string: step1And2URL)!)
        request1.httpMethod = "GET"
        request1.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request1.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request1.setValue("zh-CN,zh;q=0.9", forHTTPHeaderField: "Accept-Language")

        let (data1, response1) = try await session.data(for: request1)
        guard let httpResponse1 = response1 as? HTTPURLResponse
        else
        {
            throw NSError(domain: "Step1Failed", code: 500)
        }

        extractCookies(from: httpResponse1)
        let html = String(data: data1, encoding: .utf8) ?? ""

        // 提取 execution
        guard let range = html.range(of: #"name="execution"\s+value="([^"]+)""#, options: .regularExpression)
        else
        {
            throw NSError(domain: "ExecutionNotFound", code: 404)
        }

        let matchedText = String(html[range])
        guard let valueStart = matchedText.range(of: "value=\""),
              let valueEnd = matchedText.range(of: "\"", range: valueStart.upperBound ..< matchedText.endIndex)
        else
        {
            throw NSError(domain: "ExecutionParseError", code: 404)
        }

        let execution = String(matchedText[valueStart.upperBound ..< valueEnd.lowerBound])
        print("✅ Execution获取成功")

        // Step 2: POST 提交登录表单
        print("🔐 Step 2: 提交登录信息")
        var request2 = URLRequest(url: URL(string: step1And2URL)!)
        request2.httpMethod = "POST"
        request2.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request2.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request2.setValue(step1And2URL, forHTTPHeaderField: "Referer")
        request2.setValue("https://cas-paas.hzau.edu.cn", forHTTPHeaderField: "Origin")

        let cookieHeader = getCookieHeader()
        if !cookieHeader.isEmpty
        {
            request2.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }

        func formEncode(_ str: String) -> String
        {
            var allowed = CharacterSet.alphanumerics
            allowed.insert(charactersIn: "-_.~")
            return str.addingPercentEncoding(withAllowedCharacters: allowed) ?? str
        }

        let bodyString = [
            "username=\(formEncode(username))",
            "password=\(formEncode(rsaPassword))",
            "execution=\(formEncode(execution))",
            "_eventId=submit",
            "currentMenu=1",
            "failN=0",
            "submit1=Login1",
            "fpVisitorId=cf1df3e32fe5f29e9c91952fed0edc7e",
        ].joined(separator: "&")

        request2.httpBody = bodyString.data(using: .utf8)

        let (data2, response2) = try await session.data(for: request2)
        guard let httpResponse2 = response2 as? HTTPURLResponse
        else
        {
            throw NSError(domain: "Step2Failed", code: 500)
        }

        if httpResponse2.statusCode == 200
        {
            let responseText = String(data: data2, encoding: .utf8) ?? ""
            throw NSError(domain: "LoginFailed", code: 401, userInfo: ["response": responseText])
        }

        guard let location3 = httpResponse2.allHeaderFields["Location"] as? String
        else
        {
            throw NSError(domain: "NoLocationStep2", code: 401)
        }

        extractCookies(from: httpResponse2)

        // Step 3: GET Ticket 链接
        print("🔐 Step 3: 获取Ticket")
        var request3 = URLRequest(url: URL(string: location3)!)
        request3.httpMethod = "GET"
        request3.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let (_, response3) = try await session.data(for: request3)
        guard let httpResponse3 = response3 as? HTTPURLResponse
        else
        {
            throw NSError(domain: "Step3Failed", code: 500)
        }

        extractCookies(from: httpResponse3)

        // 从 cookieJar 中提取 JSESSIONID
        if let jsessionId = cookieJar["JSESSIONID"]
        {
            let cookie = "JSESSIONID=\(jsessionId)"
            print("✅ 登录成功，获得Cookie")
            return cookie
        }

        throw NSError(domain: "CookieNotFound", code: 404)
    }

    // MARK: - 查询课表

    func fetchCourses(cookie: String, xnm: String, xqm: String) async throws -> [Course]
    {
        print("📚 开始查询课表...")
        print("   学年: \(xnm), 学期: \(xqm)")

        var request = URLRequest(url: URL(string: courseQueryURL)!)
        request.httpMethod = "POST"

        // 设置请求头
        request.setValue("application/x-www-form-urlencoded;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue("http://byjxyt.hzau.edu.cn/kbcx/xskbcx_cxXskbcxIndex.html?gnmkdm=N2151&layout=default", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue(cookie, forHTTPHeaderField: "Cookie")

        // 构建请求体（这里可能需要根据实际情况调整参数）
        let params: [String: String] = [
            "xnm": xnm,
            "xqm": xqm,
        ]

        request.httpBody = params
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        do
        {
            let (data, _) = try await session.data(for: request)
            let jsonString = String(data: data, encoding: .utf8) ?? ""

            // 解析 JSON
            let decoder = JSONDecoder()
            let response = try decoder.decode(ScheduleResponse.self, from: data)

            print("✅ 课表查询成功，共 \(response.kbList.count) 门课程")

            // 打印课程信息（调试用）
            for course in response.kbList.prefix(3)
            {
                print("   📖 \(course.kcmc) | \(course.xqjmc ?? "周\(course.xqj)") \(course.formattedJcs) | \(course.cdmc ?? "无教室")")
            }
            if response.kbList.count > 3
            {
                print("   ... 还有 \(response.kbList.count - 3) 门课程")
            }

            return response.kbList
        }
        catch let error as DecodingError
        {
            print("❌ JSON解析失败: \(error)")
            throw NSError(domain: "JSONDecodingFailed", code: 500, userInfo: ["error": error.localizedDescription])
        }
        catch
        {
            print("❌ 请求失败: \(error.localizedDescription)")
            throw error
        }
    }
}
