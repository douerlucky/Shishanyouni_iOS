// 学校教学平台登录与课表请求；从旧 Backup 文件迁出的正式实现。

import Foundation

class SchoolAcademicAPI: NSObject, URLSessionTaskDelegate
{
    static let byjxytLoginServiceURL = "https://cas-paas.hzau.edu.cn/cas/login?service=http%3A%2F%2Fbyjxyt.hzau.edu.cn%2Fswlogin"
    static let jwglLoginServiceURL = "https://cas-paas.hzau.edu.cn/cas/login?service=http%3A%2F%2Fjwgl.hzau.edu.cn%2Fsso%2Fhnyyxyiotlogin%3FtargetUrl%3D%7Bbase64%7DaHR0cDovL2p3Z2wuaHphdS5lZHUuY24vc3NvL3Nzby9pbmRleC5qc3A%3D"

    private let step1And2URL: String
    private let followServiceRedirects: Bool
    private let sessionConfiguration: URLSessionConfiguration
    private let mfaDetectURL = "https://cas-paas.hzau.edu.cn/cas/mfa/detect"
    private let mfaInitSecurePhoneURL = "https://cas-paas.hzau.edu.cn/cas/mfa/initByType/securephone"
    private let courseQueryURL = "http://byjxyt.hzau.edu.cn/kbcx/xskbcx_cxXsKb.html?gnmkdm=N2151"
    
    // 按 Domain + Path + Name 保存，避免 CAS 的 SESSION 被误发给 jwgl。
    private var cookieJar: [String: HTTPCookie] = [:]

    init(
        serviceURL: String = SchoolAcademicAPI.byjxytLoginServiceURL,
        followServiceRedirects: Bool = false,
        sessionConfiguration: URLSessionConfiguration = .ephemeral
    )
    {
        step1And2URL = serviceURL
        self.followServiceRedirects = followServiceRedirects
        self.sessionConfiguration = sessionConfiguration
        super.init()
    }
    
    private lazy var session: URLSession = {
        let config = sessionConfiguration
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
        let headerFields = response.allHeaderFields.reduce(into: [String: String]())
        {
            partialResult, item in
            if let key = item.key as? String, let value = item.value as? String
            {
                partialResult[key] = value
            }
        }
        let cookies = HTTPCookie.cookies(
            withResponseHeaderFields: headerFields,
            for: response.url ?? URL(string: step1And2URL)!
        )
        for cookie in cookies
        {
            let key = "\(cookie.domain)|\(cookie.path)|\(cookie.name)"
            cookieJar[key] = cookie
            print("保存 Cookie[\(cookie.domain)]: \(cookie.name)")
        }
    }
    
    private func getCookieHeader(for url: URL? = nil, includeAllPaths: Bool = false) -> String
    {
        let cookies = cookieJar.values.filter
        { cookie in
            guard let url else { return true }
            guard let host = url.host?.lowercased() else { return false }
            let domain = cookie.domain
                .lowercased()
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            let domainMatches = host == domain || host.hasSuffix(".\(domain)")
            // 教务系统的 JSESSIONID 偶尔会被标成 /sso，但后续成绩接口位于 /cjcx。
            // 登录票据请求仍按标准 Path 过滤；返回给教务接口时会显式放宽 Path。
            let pathMatches = includeAllPaths || url.path.isEmpty || url.path.hasPrefix(cookie.path)
            let secureMatches = !cookie.isSecure || url.scheme?.lowercased() == "https"
            let hasNotExpired = cookie.expiresDate.map { $0 > Date() } ?? true
            return domainMatches && pathMatches && secureMatches && hasNotExpired
        }

        // 一个会话有时同时返回 `/` 和 `/sso` 两个同名 JSESSIONID。
        // Cookie 请求头不能重复发送同名值：放宽 Path 时优先根路径，
        // 标准 Path 过滤时优先更具体的路径。
        let uniqueCookies = cookies.reduce(into: [String: HTTPCookie]())
        { result, cookie in
            guard let existing = result[cookie.name] else
            {
                result[cookie.name] = cookie
                return
            }

            let shouldReplace = includeAllPaths
                ? cookie.path.count < existing.path.count
                : cookie.path.count > existing.path.count
            if shouldReplace
            {
                result[cookie.name] = cookie
            }
        }

        return uniqueCookies.values
            .sorted { $0.name < $1.name }
            .map { "\($0.name)=\($0.value)" }
            .joined(separator: "; ")
    }

    private func finishLoginWithTicketLocation(_ location: String) async throws -> String
    {
        print("🔐 获取教务 Ticket")
        guard let url = URL(string: location) else { throw NSError(domain: "InvalidURL", code: 400) }
        print("🔐 已取得教务 Ticket 跳转。")

        var currentURL = url
        for redirectCount in 0 ... 10
        {
            var request = URLRequest(url: currentURL)
            request.httpMethod = "GET"
            let cookieHeader = getCookieHeader(for: currentURL)
            if !cookieHeader.isEmpty
            {
                request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
            }
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else
            {
                throw NSError(domain: "TicketLoginFailed", code: 500)
            }

            extractCookies(from: httpResponse)

            if followServiceRedirects,
               (300 ..< 400).contains(httpResponse.statusCode),
               let redirectLocation = httpResponse.value(forHTTPHeaderField: "Location"),
               let redirectURL = URL(string: redirectLocation, relativeTo: currentURL)?.absoluteURL
            {
                guard redirectCount < 10 else
                {
                    throw NSError(domain: "TooManyServiceRedirects", code: 310)
                }
                currentURL = redirectURL
                print("🔐 跟随教务跳转: \(redirectURL.absoluteString)")
                continue
            }

            let responseURL = httpResponse.url ?? currentURL
            let serviceCookieHeader = getCookieHeader(for: responseURL, includeAllPaths: true)
            let responseText = String(data: data, encoding: .utf8)?.lowercased() ?? ""
            let responsePath = responseURL.path.lowercased()
            let isAcademicLoginPage = responsePath.contains("/xtgl/login")
                || responseText.contains("cas-paas.hzau.edu.cn/cas/login")
                || responseText.contains("name=\"execution\"")
                || responseText.contains("统一身份认证")

            if !serviceCookieHeader.isEmpty && !isAcademicLoginPage
            {
                print("✅ 登录成功，获得 \(responseURL.host ?? "教务系统") Cookie")
                return serviceCookieHeader
            }

            if isAcademicLoginPage
            {
                throw NSError(
                    domain: "AcademicLoginFailed",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "教务系统未接受 CAS 登录票据，请重试查询。"]
                )
            }

            break
        }

        throw NSError(domain: "CookieNotFound", code: 404)
    }

    private func formEncode(_ str: String) -> String
    {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.~")
        return str.addingPercentEncoding(withAllowedCharacters: allowed) ?? str
    }

    private func performMFAIfNeeded(username: String, password: String, mfaCodeProvider: MFACodeProvider?) async throws -> String
    {
        if CASClientEnvironment.forcePromptEnabled
        {
            guard let provider = mfaCodeProvider else
            {
                throw CASMFAError.needCodeInput
            }
            let code = await MFACodeContext.requestCode(
                using: provider,
                maskedPhone: CASClientEnvironment.maskedPhone,
                sendCodeAction: { nil }
            )
            guard let code, !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else
            {
                throw CASMFAError.cancelled
            }
            return ""
        }

        var detectRequest = URLRequest(url: URL(string: mfaDetectURL)!)
        detectRequest.httpMethod = "POST"
        detectRequest.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        detectRequest.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        detectRequest.setValue(getCookieHeader(), forHTTPHeaderField: "Cookie")
        detectRequest.setValue(step1And2URL, forHTTPHeaderField: "Referer")
        detectRequest.setValue("https://cas-paas.hzau.edu.cn", forHTTPHeaderField: "Origin")
        detectRequest.httpBody = [
            "username=\(formEncode(username))",
            "password=\(formEncode(password))",
            "fpVisitorId=\(formEncode(CASClientEnvironment.fpVisitorId))",
        ].joined(separator: "&").data(using: .utf8)

        let (detectData, detectResponse) = try await session.data(for: detectRequest)
        guard let detectHTTP = detectResponse as? HTTPURLResponse else
        {
            throw NSError(domain: "MFADetectFailed", code: 500)
        }
        extractCookies(from: detectHTTP)

        let detect = try JSONDecoder().decode(CASMFADetectResponse.self, from: detectData)
        guard detect.code == 0, let detectInfo = detect.data else
        {
            throw CASMFAError.initFailed
        }
        print("[MFA][Schedule] detect need=\(detectInfo.need), securePhone=\(detectInfo.mfaTypeSecurePhone ?? false)")
        // state 是本次登录检测凭证；免短信验证也必须随表单提交。
        guard let state = detectInfo.state, !state.isEmpty else
        {
            throw CASMFAError.initFailed
        }
        guard detectInfo.need else
        {
            print("[MFA][Schedule] 无需短信验证，保留检测凭证继续登录。")
            return state
        }
        guard (detectInfo.mfaTypeSecurePhone ?? false) else
        {
            throw CASMFAError.unsupportedType
        }
        guard let provider = mfaCodeProvider else
        {
            throw CASMFAError.needCodeInput
        }

        var initComponents = URLComponents(string: mfaInitSecurePhoneURL)!
        initComponents.queryItems = [URLQueryItem(name: "state", value: state)]
        var initRequest = URLRequest(url: initComponents.url!)
        initRequest.httpMethod = "GET"
        initRequest.setValue(getCookieHeader(), forHTTPHeaderField: "Cookie")
        initRequest.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        let (initData, initResponse) = try await session.data(for: initRequest)
        guard let initHTTP = initResponse as? HTTPURLResponse else
        {
            throw NSError(domain: "MFAInitFailed", code: 500)
        }
        extractCookies(from: initHTTP)

        let initResult = try JSONDecoder().decode(CASMFAInitResponse.self, from: initData)
        guard initResult.code == 0, let initInfo = initResult.data else
        {
            throw CASMFAError.initFailed
        }

        let sendCodeAction: () async -> String? = {
            do
            {
                var sendRequest = URLRequest(url: URL(string: initInfo.attestServerUrl + "/api/guard/securephone/send")!)
                sendRequest.httpMethod = "POST"
                sendRequest.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
                sendRequest.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
                sendRequest.setValue(self.getCookieHeader(), forHTTPHeaderField: "Cookie")
                sendRequest.httpBody = try JSONSerialization.data(withJSONObject: ["gid": initInfo.gid], options: [])

                let (sendData, sendResponse) = try await self.session.data(for: sendRequest)
                guard let sendHTTP = sendResponse as? HTTPURLResponse else
                {
                    return CASMFAError.sendFailed.localizedDescription
                }
                self.extractCookies(from: sendHTTP)
                let sendResult = try JSONDecoder().decode(CASMFACommonResponse.self, from: sendData)
                return sendResult.code == 0 ? nil : CASMFAError.sendFailed.localizedDescription
            }
            catch
            {
                return error.localizedDescription
            }
        }

        let code = await MFACodeContext.requestCode(
            using: provider,
            maskedPhone: initInfo.securePhone,
            sendCodeAction: sendCodeAction
        )
        guard let code, !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else
        {
            throw CASMFAError.cancelled
        }

        var validRequest = URLRequest(url: URL(string: initInfo.attestServerUrl + "/api/guard/securephone/valid")!)
        validRequest.httpMethod = "POST"
        validRequest.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        validRequest.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        validRequest.setValue(getCookieHeader(), forHTTPHeaderField: "Cookie")
        validRequest.httpBody = try JSONSerialization.data(withJSONObject: ["gid": initInfo.gid, "code": code], options: [])

        let (validData, validResponse) = try await session.data(for: validRequest)
        guard let validHTTP = validResponse as? HTTPURLResponse else
        {
            throw NSError(domain: "MFAValidFailed", code: 500)
        }
        extractCookies(from: validHTTP)
        let validResult = try JSONDecoder().decode(CASMFACommonResponse.self, from: validData)
        guard validResult.code == 0, validResult.data?.status == 2 else
        {
            throw CASMFAError.verifyFailed
        }

        return state
    }
    
    // MARK: - 登录获取Cookie
    
    func loginAndGetCookie(username: String, rsaPassword: String, mfaCodeProvider: MFACodeProvider? = nil) async throws -> String
    {
        // 每次查询都建立新会话，避免上一次失效的 Cookie 混入本次请求。
        cookieJar.removeAll()

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

        if let location = httpResponse1.allHeaderFields["Location"] as? String
        {
            print("✨ 复用 CAS 登录态换取教务 Cookie")
            return try await finishLoginWithTicketLocation(location)
        }

        let html = String(data: data1, encoding: .utf8) ?? ""
        
        // 提取 execution
        guard let range = html.range(of: #"name="execution"\s+value="([^"]+)""#, options: .regularExpression)
        else
        {
            print("❌ CAS 页面未找到 execution，状态码: \(httpResponse1.statusCode)，片段: \(html.prefix(200))")
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
        
        let mfaState = try await performMFAIfNeeded(username: username, password: rsaPassword, mfaCodeProvider: mfaCodeProvider)

        // MFA 检测/验证可能更新会话，最终提交使用最新 Cookie。
        let cookieHeader = getCookieHeader(for: request2.url)
        if !cookieHeader.isEmpty
        {
            request2.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }
        
        let bodyString = [
            "username=\(formEncode(username))",
            "password=\(formEncode(rsaPassword))",
            "captcha=",
            "currentMenu=1",
            "failN=0",
            "mfaState=\(formEncode(mfaState))",
            "execution=\(formEncode(execution))",
            "_eventId=submit",
            "geolocation=",
            "submit1=Login1",
            "fpVisitorId=\(formEncode(CASClientEnvironment.fpVisitorId))",
        ].joined(separator: "&")
        
        request2.httpBody = bodyString.data(using: .utf8)
        
        let (data2, response2) = try await session.data(for: request2)
        guard let httpResponse2 = response2 as? HTTPURLResponse
        else
        {
            throw NSError(domain: "Step2Failed", code: 500)
        }
        
        extractCookies(from: httpResponse2)

        if httpResponse2.statusCode == 200
        {
            throw CASLoginFailure.error(from: data2)
        }
        
        guard let location3 = httpResponse2.allHeaderFields["Location"] as? String
        else
        {
            throw NSError(domain: "NoLocationStep2", code: 401)
        }
        
        return try await finishLoginWithTicketLocation(location3)
    }
    
    // MARK: - 查询课表
    
//    func fetchCourses(cookie: String, xnm: String, xqm: String) async throws -> [Course]
//    {
//        print("📚 开始查询课表...")
//        print("   学年: \(xnm), 学期: \(xqm)")
//        
//        var request = URLRequest(url: URL(string: courseQueryURL)!)
//        request.httpMethod = "POST"
//        
//        // 设置请求头
//        request.setValue("application/x-www-form-urlencoded;charset=UTF-8", forHTTPHeaderField: "Content-Type")
//        request.setValue("*/*", forHTTPHeaderField: "Accept")
//        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
//        request.setValue("http://byjxyt.hzau.edu.cn/kbcx/xskbcx_cxXskbcxIndex.html?gnmkdm=N2151&layout=default", forHTTPHeaderField: "Referer")
//        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
//        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
//        request.setValue(cookie, forHTTPHeaderField: "Cookie")
//        
//        // 构建请求体 - 添加更多必要参数
//        let params: [String: String] = [
//            "xnm": xnm,
//            "xqm": xqm,
//            "_search": "false",
//            "nd": String(Int(Date().timeIntervalSince1970 * 1000)),
//            "queryModel.showCount": "100",
//            "queryModel.currentPage": "1",
//            "queryModel.sortName": "",
//            "queryModel.sortOrder": "asc",
//            "time": "0"
//        ]
//        
//        let bodyString = params
//            .map { "\($0.key)=\($0.value)" }
//            .joined(separator: "&")
//        
//        print("📤 请求参数: \(bodyString)")
//        request.httpBody = bodyString.data(using: .utf8)
//        
//        do
//        {
//            let (data, response) = try await session.data(for: request)
//            
//            // 打印原始响应数据用于调试
//            if let jsonString = String(data: data, encoding: .utf8) {
//                print("📥 原始响应: \(jsonString)")
//            }
//            
//            guard let httpResponse = response as? HTTPURLResponse else {
//                throw NSError(domain: "InvalidResponse", code: 500, userInfo: [NSLocalizedDescriptionKey: "无效的响应类型"])
//            }
//            
//            print("📥 响应状态码: \(httpResponse.statusCode)")
//            
//            // 检查响应状态码
//            guard httpResponse.statusCode == 200 else {
//                throw NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP错误: \(httpResponse.statusCode)"])
//            }
//            
//            // 解析 JSON
//            let decoder = JSONDecoder()
//            
//            do {
//                let response = try decoder.decode(ScheduleResponse.self, from: data)
//                print("✅ 课表查询成功，共 \(response.kbList.count) 门课程")
//                
//                // 打印课程信息（调试用）
//                for course in response.kbList.prefix(3)
//                {
//                    print("   📖 \(course.kcmc) | \(course.xqjmc ?? "周\(course.xqj)") \(course.formattedJcs) | \(course.cdmc ?? "无教室")")
//                }
//                if response.kbList.count > 3
//                {
//                    print("   ... 还有 \(response.kbList.count - 3) 门课程")
//                }
//                
//                return response.kbList
//            } catch let decodingError as DecodingError {
//                // 详细打印解码错误
//                print("❌ JSON解析失败: \(decodingError)")
//                
//                // 根据解码错误类型提供更详细的信息
//                switch decodingError {
//                case .keyNotFound(let key, let context):
//                    print("   缺失键: \(key.stringValue)")
//                    print("   路径: \(context.codingPath)")
//                    throw NSError(domain: "JSONDecodingFailed", code: 500, userInfo: [
//                        NSLocalizedDescriptionKey: "JSON解析失败：缺少字段 '\(key.stringValue)'"
//                    ])
//                    
//                case .valueNotFound(let type, let context):
//                    print("   值缺失: \(type)")
//                    print("   路径: \(context.codingPath)")
//                    throw NSError(domain: "JSONDecodingFailed", code: 500, userInfo: [
//                        NSLocalizedDescriptionKey: "JSON解析失败：缺少值，期望类型 \(type)"
//                    ])
//                    
//                case .typeMismatch(let type, let context):
//                    print("   类型不匹配: 期望 \(type)")
//                    print("   路径: \(context.codingPath)")
//                    throw NSError(domain: "JSONDecodingFailed", code: 500, userInfo: [
//                        NSLocalizedDescriptionKey: "JSON解析失败：类型不匹配，期望 \(type)"
//                    ])
//                    
//                case .dataCorrupted(let context):
//                    print("   数据损坏: \(context.debugDescription)")
//                    throw NSError(domain: "JSONDecodingFailed", code: 500, userInfo: [
//                        NSLocalizedDescriptionKey: "JSON解析失败：数据损坏 - \(context.debugDescription)"
//                    ])
//                    
//                @unknown default:
//                    throw NSError(domain: "JSONDecodingFailed", code: 500, userInfo: [
//                        NSLocalizedDescriptionKey: "JSON解析失败：未知错误"
//                    ])
//                }
//            }
//        }
//        catch let error as DecodingError
//        {
//            print("❌ JSON解析失败: \(error)")
//            throw NSError(domain: "JSONDecodingFailed", code: 500, userInfo: ["error": error.localizedDescription])
//        }
//        catch
//        {
//            print("❌ 请求失败: \(error.localizedDescription)")
//            throw error
//        }
//    }
}
