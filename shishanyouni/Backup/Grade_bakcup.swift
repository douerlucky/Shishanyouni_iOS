////
////  Grade.swift
////  shishanyouni
////
////  Created by douer_lucky on 2026/2/6.
////
//
//import Foundation
//
//struct GradeResponse: Decodable
//{
//    let items: [Grade]
//}
//
//struct Grade: Identifiable, Decodable
//{
//    // 用key当id
//    let key: String
//    var id: String { key }
//
//    let kcmc: String // 课程名称
//    let cj: String // 成绩
//    let xf: String // 学分
//    let jd: String // 绩点
//    let jsxm: String // 教师姓名
//}
//
//class GradeQuery: NSObject, URLSessionTaskDelegate
//{
//    private let step1And2URL = "https://cas-paas.hzau.edu.cn/cas/login?service=http%3A%2F%2Fjwgl.hzau.edu.cn%2Fsso%2Fhnyyxyiotlogin%3FtargetUrl%3D%7Bbase64%7DaHR0cDovL2p3Z2wuaHphdS5lZHUuY24vc3NvL3Nzby9pbmRleC5qc3A%3D"
//
//    // 手动存储 cookies
//    private var cookieJar: [String: String] = [:]
//
//    private lazy var session: URLSession = {
//        let config = URLSessionConfiguration.default
//        // 禁用自动 cookie 管理，改为手动
//        config.httpCookieStorage = nil
//        config.httpShouldSetCookies = false
//        config.httpCookieAcceptPolicy = .never
//        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
//    }()
//
//    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest: URLRequest, completionHandler: @escaping (URLRequest?) -> Void)
//    {
//        completionHandler(nil)
//    }
//
//    // 手动提取和存储 cookies
//    private func extractCookies(from response: HTTPURLResponse)
//    {
//        if let setCookies = response.allHeaderFields["Set-Cookie"] as? String
//        {
//            // 可能有多个 Set-Cookie，用逗号分隔
//            let cookies = setCookies.components(separatedBy: ",")
//            for cookie in cookies
//            {
//                if let nameValuePair = cookie.components(separatedBy: ";").first
//                {
//                    let parts = nameValuePair.trimmingCharacters(in: .whitespaces).components(separatedBy: "=")
//                    if parts.count == 2
//                    {
//                        cookieJar[parts[0]] = parts[1]
//                        print("保存: \(parts[0])=\(parts[1].prefix(20))...")
//                    }
//                }
//            }
//        }
//    }
//
//    // 手动构建 Cookie header
//    private func getCookieHeader() -> String
//    {
//        return cookieJar.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
//    }
//
//    func loginAndGetCookie(username: String, rsaPassword: String) async throws -> String
//    {
//        // Step 1: GET 获取 Execution
//        print("Step 1: GET 获取 Execution")
//        print("URL: \(step1And2URL)")
//
//        var request1 = URLRequest(url: URL(string: step1And2URL)!)
//        request1.httpMethod = "GET"
//        request1.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
//        request1.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
//        request1.setValue("zh-CN,zh;q=0.9", forHTTPHeaderField: "Accept-Language")
//
//        let (data1, response1) = try await session.data(for: request1)
//        guard let httpResponse1 = response1 as? HTTPURLResponse
//        else
//        {
//            throw NSError(domain: "Step1Failed", code: 500)
//        }
//        print("Status: \(httpResponse1.statusCode)")
//
//        // 手动提取 cookies
//        print("Step 1 提取 Cookies:")
//        extractCookies(from: httpResponse1)
//
//        let html = String(data: data1, encoding: .utf8) ?? ""
//
//        // 提取 execution
//        guard let range = html.range(of: #"name="execution"\s+value="([^"]+)""#, options: .regularExpression)
//        else
//        {
//            print("未找到 execution")
//            throw NSError(domain: "ExecutionNotFound", code: 404)
//        }
//
//        let matchedText = String(html[range])
//        guard let valueStart = matchedText.range(of: "value=\""),
//              let valueEnd = matchedText.range(of: "\"", range: valueStart.upperBound ..< matchedText.endIndex)
//        else
//        {
//            throw NSError(domain: "ExecutionParseError", code: 404)
//        }
//
//        let execution = String(matchedText[valueStart.upperBound ..< valueEnd.lowerBound])
//        print("Execution: \(execution.prefix(50))...")
//
//        // ===== Step 2: POST 提交表单 =====
//        print("\nStep 2: POST 提交表单")
//        print("URL: \(step1And2URL)")
//
//        var request2 = URLRequest(url: URL(string: step1And2URL)!)
//        request2.httpMethod = "POST"
//        request2.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
//        request2.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
//        request2.setValue(step1And2URL, forHTTPHeaderField: "Referer")
//        request2.setValue("https://cas-paas.hzau.edu.cn", forHTTPHeaderField: "Origin")
//
//        // 手动添加 Cookie header
//        let cookieHeader = getCookieHeader()
//        if !cookieHeader.isEmpty
//        {
//            request2.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
//            print("发送 Cookies: \(cookieHeader.prefix(100))...")
//        }
//        else
//        {
//            print("警告：没有 cookies 可发送")
//        }
//
//        // 使用正确的 form-urlencoded 编码方式
//        func formEncode(_ str: String) -> String
//        {
//            var allowed = CharacterSet.alphanumerics
//            allowed.insert(charactersIn: "-_.~") // 只保留这几个符号不编码
//            return str.addingPercentEncoding(withAllowedCharacters: allowed) ?? str
//        }
//
//        let bodyString = [
//            "username=\(formEncode(username))",
//            "password=\(formEncode(rsaPassword))",
//            "execution=\(formEncode(execution))",
//            "_eventId=submit",
//            "currentMenu=1",
//            "failN=0",
//            "submit1=Login1",
//            "fpVisitorId=cf1df3e32fe5f29e9c91952fed0edc7e",
//        ].joined(separator: "&")
//
//        request2.httpBody = bodyString.data(using: .utf8)
//
//        let (data2, response2) = try await session.data(for: request2)
//        guard let httpResponse2 = response2 as? HTTPURLResponse
//        else
//        {
//            throw NSError(domain: "Step2Failed", code: 500)
//        }
//        print("Status: \(httpResponse2.statusCode)")
//
//        if httpResponse2.statusCode == 200
//        {
//            let responseText = String(data: data2, encoding: .utf8) ?? ""
//            print("登录失败，返回内容前 500 字符:")
//            print(responseText.prefix(500))
//            throw NSError(domain: "LoginFailed", code: 401, userInfo: ["response": responseText])
//        }
//
//        guard let location3 = httpResponse2.allHeaderFields["Location"] as? String
//        else
//        {
//            print("Step 2 未获取到 Location")
//            throw NSError(domain: "NoLocationStep2", code: 401)
//        }
//        print("Location: \(location3)")
//
//        // Step 2 也可能返回新的 cookies
//        extractCookies(from: httpResponse2)
//
//        // Step 3: GET Ticket 链接
//        print("Step 3: GET Ticket 链接")
//        print("URL: \(location3)")
//
//        var request3 = URLRequest(url: URL(string: location3)!)
//        request3.httpMethod = "GET"
//        request3.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
//
//        let (_, response3) = try await session.data(for: request3)
//        guard let httpResponse3 = response3 as? HTTPURLResponse
//        else
//        {
//            throw NSError(domain: "Step3Failed", code: 500)
//        }
//        print("Status: \(httpResponse3.statusCode)")
//
//        guard let location4 = httpResponse3.allHeaderFields["Location"] as? String
//        else
//        {
//            print("Step 3 未获取到 Location")
//            throw NSError(domain: "NoLocationStep3", code: 401)
//        }
//        print("Location: \(location4)")
//
//        extractCookies(from: httpResponse3)
//
//        // ===== Step 4: GET 最终链接 =====
//        print("\nStep 4: GET 最终链接")
//        print(" URL: \(location4)")
//
//        var request4 = URLRequest(url: URL(string: location4)!)
//        request4.httpMethod = "GET"
//        request4.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
//
//        let (_, response4) = try await session.data(for: request4)
//        guard let httpResponse4 = response4 as? HTTPURLResponse
//        else
//        {
//            throw NSError(domain: "Step4Failed", code: 500)
//        }
//        print(" Status: \(httpResponse4.statusCode)")
//
//        extractCookies(from: httpResponse4)
//
//        // 从 cookieJar 中提取 JSESSIONID
//        if let jsessionId = cookieJar["JSESSIONID"]
//        {
//            let cookie = "JSESSIONID=\(jsessionId)"
//            print("成功获得 \(cookie)")
//            return cookie
//        }
//
//        throw NSError(domain: "CookieNotFound", code: 404)
//    }
//
//    func fetchGrades(cookie: String, xnm: String, xqm: String) async -> [Grade]
//    {
//        var status: String = "请求中…"
//        var rawJSON: String = ""
//        var parsedGrades: [Grade] = []
//
//        var req = URLRequest(url: URL(string: "http://jwgl.hzau.edu.cn/cjcx/cjcx_cxXsgrcj.html?doType=query&gnmkdm=N305005")!)
//        req.httpMethod = "POST"
//
//        // headers（尽量贴近浏览器）
//        req.setValue("application/x-www-form-urlencoded;charset=UTF-8", forHTTPHeaderField: "Content-Type")
//        req.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
//        req.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
//        req.setValue("http://jwgl.hzau.edu.cn/cjcx/cjcx_cxDgXscj.html?gnmkdm=N305005&layout=default", forHTTPHeaderField: "Referer")
//        req.setValue(cookie, forHTTPHeaderField: "Cookie") // 你手动粘贴的 JSESSIONID=xxx
//
//        // body（你 postman 里那几个）
//        let kb = String(Int(Date().timeIntervalSince1970 * 1000))
//        let params: [String: String] = [
//            "xnm": xnm,
//            "xqm": xqm,
//            "_kb": kb,
//            "queryModel.showCount": "50",
//            "queryModel.currentPage": "1",
//            "queryModel.sortName": "",
//            "queryModel.sortOrder": "asc",
//        ]
//        req.httpBody = params
//            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
//            .joined(separator: "&")
//            .data(using: .utf8)
//
//        do
//        {
//            let (data, _) = try await session.data(for: req)
//            let jsonString = String(data: data, encoding: .utf8) ?? ""
//            rawJSON = jsonString
//
//            // 必须加上这一段解析逻辑！
//            if let decodedResponse = try? JSONDecoder().decode(GradeResponse.self, from: data)
//            {
//                parsedGrades = decodedResponse.items
//                status = "查询成功，共 \(parsedGrades.count) 门课"
//                print("解析成功: \(parsedGrades.count) 门课程")
//            }
//            else
//            {
//                status = "JSON 解析失败"
//                print("解析失败，请检查 Grade 结构体字段是否匹配")
//            }
//        }
//        catch
//        {
//            status = "失败：\(error.localizedDescription)"
//        }
//        return parsedGrades
//    }
//}
