//
//  Course.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/10.
//

import Foundation

struct CourseResponse: Decodable
{
    let kbList: [Course]
}

struct Course: Identifiable, Decodable
{
    let kcmc: String // 课程名称
    let xqj: String // 星期几
    let jcs: String // 节次
    let cdmc: String? // 场地名称（教室）
    let xm: String? // 教师姓名
    let zcd: String? // 周次
    
    var id: String {
        "\(kcmc)_\(xqj)_\(jcs)"
    }
}

class CourseQuery: NSObject, URLSessionTaskDelegate
{
    private let step1And2URL = "https://cas-paas.hzau.edu.cn/cas/login?service=http%3A%2F%2Fbyjxyt.hzau.edu.cn%2Fswlogin"

    // 手动存储 cookies
    private var cookieJar: [String: String] = [:]

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        // 禁用自动 cookie 管理，改为手动
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest: URLRequest, completionHandler: @escaping (URLRequest?) -> Void)
    {
        completionHandler(nil)
    }

    // 手动提取和存储 cookies
    private func extractCookies(from response: HTTPURLResponse)
    {
        if let setCookies = response.allHeaderFields["Set-Cookie"] as? String
        {
            // 可能有多个 Set-Cookie，用逗号分隔
            let cookies = setCookies.components(separatedBy: ",")
            for cookie in cookies
            {
                if let nameValuePair = cookie.components(separatedBy: ";").first
                {
                    let parts = nameValuePair.trimmingCharacters(in: .whitespaces).components(separatedBy: "=")
                    if parts.count == 2
                    {
                        cookieJar[parts[0]] = parts[1]
                        print("保存: \(parts[0])=\(parts[1].prefix(20))...")
                    }
                }
            }
        }
    }

    // 手动构建 Cookie header
    private func getCookieHeader() -> String
    {
        return cookieJar.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
    }

    func loginAndGetCookie(username: String, rsaPassword: String) async throws -> String
    {
        // Step 1: GET 获取 Execution
        print("Step 1: GET 获取 Execution")
        print("URL: \(step1And2URL)")

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
        print("Status: \(httpResponse1.statusCode)")

        // 手动提取 cookies
        print("Step 1 提取 Cookies:")
        extractCookies(from: httpResponse1)

        let html = String(data: data1, encoding: .utf8) ?? ""

        // 提取 execution
        guard let range = html.range(of: #"name="execution"\s+value="([^"]+)""#, options: .regularExpression)
        else
        {
            print("未找到 execution")
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
        print("Execution: \(execution.prefix(50))...")

        // Step 2: POST 提交表单
        print("\nStep 2: POST 提交表单")
        print("URL: \(step1And2URL)")

        var request2 = URLRequest(url: URL(string: step1And2URL)!)
        request2.httpMethod = "POST"
        request2.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request2.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request2.setValue(step1And2URL, forHTTPHeaderField: "Referer")
        request2.setValue("https://cas-paas.hzau.edu.cn", forHTTPHeaderField: "Origin")

        // 手动添加 Cookie header
        let cookieHeader = getCookieHeader()
        if !cookieHeader.isEmpty
        {
            request2.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
            print("发送 Cookies: \(cookieHeader.prefix(100))...")
        }
        else
        {
            print("警告：没有 cookies 可发送")
        }

        // 使用正确的 form-urlencoded 编码方式
        func formEncode(_ str: String) -> String
        {
            var allowed = CharacterSet.alphanumerics
            allowed.insert(charactersIn: "-_.~") // 只保留这几个符号不编码
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
        print("Status: \(httpResponse2.statusCode)")

        if httpResponse2.statusCode == 200
        {
            let responseText = String(data: data2, encoding: .utf8) ?? ""
            print("登录失败，返回内容前 500 字符:")
            print(responseText.prefix(500))
            throw NSError(domain: "LoginFailed", code: 401, userInfo: ["response": responseText])
        }

        guard let location3 = httpResponse2.allHeaderFields["Location"] as? String
        else
        {
            print("Step 2 未获取到 Location")
            throw NSError(domain: "NoLocationStep2", code: 401)
        }
        print("Location: \(location3)")

        // Step 2 也可能返回新的 cookies
        extractCookies(from: httpResponse2)

        // Step 3: GET Ticket 链接
        print("\nStep 3: GET Ticket 链接")
        print("URL: \(location3)")

        var request3 = URLRequest(url: URL(string: location3)!)
        request3.httpMethod = "GET"
        request3.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let (_, response3) = try await session.data(for: request3)
        guard let httpResponse3 = response3 as? HTTPURLResponse
        else
        {
            throw NSError(domain: "Step3Failed", code: 500)
        }
        print("Status: \(httpResponse3.statusCode)")

        extractCookies(from: httpResponse3)

        // 从 cookieJar 中提取 JSESSIONID
        if let jsessionId = cookieJar["JSESSIONID"]
        {
            let cookie = "JSESSIONID=\(jsessionId)"
            print("成功获得 \(cookie)")
            return cookie
        }

        throw NSError(domain: "CookieNotFound", code: 404)
    }

    func fetchCourses(cookie: String, xnm: String, xqm: String) async -> [Course]
    {
        var parsedCourses: [Course] = []
        print("fetchCourses 方法待实现，需要实际的课表查询接口")
        return parsedCourses
    }
}
