//
//  Course.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/10.
//  Updated by lancang on 2026/3/15 手动添加课程功能

import Foundation

// MARK: - 响应结构体

//struct ScheduleResponse: Decodable
//{
//    let kbList: [Course]
//}

// MARK: - 课程结构体

//struct Course: Identifiable, Decodable, Encodable
//{
//    let jxb_id: String // 教学班ID（唯一标识）
//    let kch_id: String // 课程ID
//    let kcmc: String // 课程名称
//    let xqj: String // 星期几（1-7）
//    let jcs: String // 节次（如"5-8"）
//    let cdmc: String? // 教室名称
//    let xm: String? // 教师姓名
//    let zcmc: String? // 教师职称
//    let jxbzc: String? // 上课班级（分号分隔）
//    let zcd: String? // 周次（如"4-5周,7-8周"）
//    let xqjmc: String? // 星期几中文（如"星期一"）
//    
//    var colorIndex: Int? = 0 //用于固定保存颜色的索引
//    
//    // 是否为手动添加的课程
//    var isManual: Bool = false
//    
//    enum CodingKeys: String, CodingKey {
//        case jxb_id, kch_id, kcmc, xqj, jcs, cdmc, xm, zcmc, jxbzc, zcd, xqjmc, colorIndex
//    }
//    // 需要添加：自定义解码器
//    init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        
//        jxb_id = try container.decode(String.self, forKey: .jxb_id)
//        kch_id = try container.decode(String.self, forKey: .kch_id)
//        kcmc = try container.decode(String.self, forKey: .kcmc)
//        xqj = try container.decode(String.self, forKey: .xqj)
//        jcs = try container.decode(String.self, forKey: .jcs)
//        cdmc = try container.decodeIfPresent(String.self, forKey: .cdmc)
//        xm = try container.decodeIfPresent(String.self, forKey: .xm)
//        zcmc = try container.decodeIfPresent(String.self, forKey: .zcmc)
//        jxbzc = try container.decodeIfPresent(String.self, forKey: .jxbzc)
//        zcd = try container.decodeIfPresent(String.self, forKey: .zcd)
//        xqjmc = try container.decodeIfPresent(String.self, forKey: .xqjmc)
//        colorIndex = try container.decodeIfPresent(Int.self, forKey: .colorIndex)
//        
//        // 从服务器导入的课程，isManual 始终为 false
//        isManual = false
//    }
//    // 明确的成员初始化方法
//    init(jxb_id: String,
//         kch_id: String,
//         kcmc: String,
//         xqj: String,
//         jcs: String,
//         cdmc: String?,
//         xm: String?,
//         zcmc: String?,
//         jxbzc: String?,
//         zcd: String?,
//         xqjmc: String?,
//         colorIndex: Int? = nil,
//         isManual: Bool = false) {
//        self.jxb_id = jxb_id
//        self.kch_id = kch_id
//        self.kcmc = kcmc
//        self.xqj = xqj
//        self.jcs = jcs
//        self.cdmc = cdmc
//        self.xm = xm
//        self.zcmc = zcmc
//        self.jxbzc = jxbzc
//        self.zcd = zcd
//        self.xqjmc = xqjmc
//        self.colorIndex = colorIndex
//        self.isManual = isManual
//    }
//    // 需要添加：自定义编码器
//    func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        
//        try container.encode(jxb_id, forKey: .jxb_id)
//        try container.encode(kch_id, forKey: .kch_id)
//        try container.encode(kcmc, forKey: .kcmc)
//        try container.encode(xqj, forKey: .xqj)
//        try container.encode(jcs, forKey: .jcs)
//        try container.encodeIfPresent(cdmc, forKey: .cdmc)
//        try container.encodeIfPresent(xm, forKey: .xm)
//        try container.encodeIfPresent(zcmc, forKey: .zcmc)
//        try container.encodeIfPresent(jxbzc, forKey: .jxbzc)
//        try container.encodeIfPresent(zcd, forKey: .zcd)
//        try container.encodeIfPresent(xqjmc, forKey: .xqjmc)
//        try container.encodeIfPresent(colorIndex, forKey: .colorIndex)
//        
//        // 注意：不编码 isManual，因为它不需要保存到服务器
//    }
//    // 使用教学班ID作为唯一标识
//    var id: String
//    {
//        if isManual {
//            return jxb_id
//        }
//        return jxb_id
//    }
//
//    // 计算属性：格式化的节次显示
//    var formattedJcs: String
//    {
//        "第\(jcs)节"
//    }
//
//    // 计算属性：班级列表
//    var classList: [String]
//    {
//        jxbzc?.components(separatedBy: ";") ?? []
//    }
//
//    var parsedWeeks: Set<Int>
//    {
//        guard let zcd = zcd else { return Set() }
//
//        var result = Set<Int>()
//
//        // 去掉"周"，按逗号分割成各个部分
//        let segments = zcd.replacingOccurrences(of: "周", with: "").components(separatedBy: ",")
//
//        for segment in segments
//        {
//            let trimmed = segment.trimmingCharacters(in: .whitespaces)
//
//            // 检查是否包含单双周标记
//            let isSingleWeek = trimmed.contains("(单)") || trimmed.contains("（单）")
//            let isDoubleWeek = trimmed.contains("(双)") || trimmed.contains("（双）")
//
//            // 移除单双周标记，提取数字部分
//            let cleanSegment = trimmed
//                .replacingOccurrences(of: "(单)", with: "")
//                .replacingOccurrences(of: "（单）", with: "")
//                .replacingOccurrences(of: "(双)", with: "")
//                .replacingOccurrences(of: "（双）", with: "")
//                .trimmingCharacters(in: .whitespaces)
//
//            if cleanSegment.contains("-")
//            {
//                // 处理范围格式 "8-9"、"13-17(单)"、"6-10(双)" 等
//                let parts = cleanSegment.components(separatedBy: "-")
//                if parts.count == 2,
//                   let start = Int(parts[0].trimmingCharacters(in: .whitespaces)),
//                   let end = Int(parts[1].trimmingCharacters(in: .whitespaces))
//                {
//                    for w in start ... end
//                    {
//                        // 如果有单周标记，只添加奇数周
//                        if isSingleWeek && w % 2 == 1
//                        {
//                            result.insert(w)
//                        }
//                        // 如果有双周标记，只添加偶数周
//                        else if isDoubleWeek && w % 2 == 0
//                        {
//                            result.insert(w)
//                        }
//                        // 没有单双周标记，添加所有周
//                        else if !isSingleWeek && !isDoubleWeek
//                        {
//                            result.insert(w)
//                        }
//                    }
//                }
//            }
//            else if let singleWeek = Int(cleanSegment)
//            {
//                // 处理单周格式 "5"、"12"、"18" 等
//                // 单周或没有标记都直接添加
//                result.insert(singleWeek)
//            }
//        }
//        return result
//    }
//}
//// 新增：手动课程创建辅助办法
//extension Course {
//    static func createManualCourse(
//        name: String,
//        weekday: Int,
//        startPeriod: Int,
//        endPeriod: Int,
//        weeks: Set<Int>,
//        location: String? = nil,
//        teacher: String? = nil
//    ) -> Course {
//        // 生成唯一ID
//        let id = "manual_\(UUID().uuidString)"
//        
//        // 格式化节次
//        let jcsString = "\(startPeriod)-\(endPeriod)"
//        
//        // 格式化周次
//        let weeksString = weeks.sorted().map { "\($0)" }.joined(separator: ",") + "周"
//        
//        return Course(
//            jxb_id: id,
//            kch_id: id,
//            kcmc: name,
//            xqj: "\(weekday)",
//            jcs: jcsString,
//            cdmc: location,
//            xm: teacher,
//            zcmc: nil,
//            jxbzc: nil,
//            zcd: weeksString,
//            xqjmc: nil,
//            colorIndex: Int.random(in: 0...31), // 随机颜色
//            isManual: true
//        )
//    }
//}
// MARK: - 课表查询类

class ScheduleQuery: NSObject, URLSessionTaskDelegate
{
    private let step1And2URL = "https://cas-paas.hzau.edu.cn/cas/login?service=http%3A%2F%2Fbyjxyt.hzau.edu.cn%2Fswlogin"
    private let mfaDetectURL = "https://cas-paas.hzau.edu.cn/cas/mfa/detect"
    private let mfaInitSecurePhoneURL = "https://cas-paas.hzau.edu.cn/cas/mfa/initByType/securephone"
    private let courseQueryURL = "https://byjxyt.hzau.edu.cn/kbcx/xskbcx_cxXsKb.html?gnmkdm=N2151"
    private let cacheNamespace = "academic"
    
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
        let headerFields = response.allHeaderFields.reduce(into: [String: String]())
        {
            partialResult, item in
            if let key = item.key as? String, let value = item.value as? String
            {
                partialResult[key] = value
            }
        }
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: response.url ?? URL(string: step1And2URL)!)
        for cookie in cookies
        {
            cookieJar[cookie.name] = cookie.value
            print("保存Cookie: \(cookie.name)=\(cookie.value.prefix(20))...")
        }
    }
    
    private func getCookieHeader() -> String
    {
        return cookieJar.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
    }

    private func loadCachedCookies(username: String)
    {
        guard let cachedCookies = CASCookieCache.load(namespace: cacheNamespace, username: username)
        else
        {
            return
        }
        cookieJar.merge(cachedCookies) { current, _ in current }
        print("🍪 已加载教务 CAS Cookie 缓存")
    }

    private func saveCachedCookies(username: String)
    {
        CASCookieCache.save(cookieJar, namespace: cacheNamespace, username: username)
    }

    private func saveCASCookiesIfAvailable(username: String)
    {
        guard cookieJar["TGC"] != nil || cookieJar["SESSION"] != nil
        else
        {
            return
        }
        saveCachedCookies(username: username)
        print("🍪 已缓存 CAS 登录态 Cookie")
    }

    private func clearCachedCookies(username: String)
    {
        cookieJar.removeAll()
        CASCookieCache.clear(namespace: cacheNamespace, username: username)
    }

    private func cachedAcademicCookieIfValid(username: String) async -> String?
    {
        guard let jsessionId = cookieJar["JSESSIONID"] else
        {
            return nil
        }

        guard let url = URL(string: "https://byjxyt.hzau.edu.cn/kbcx/xskbcx_cxXskbcxIndex.html?gnmkdm=N2151&layout=default")
        else
        {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(getCookieHeader(), forHTTPHeaderField: "Cookie")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        do
        {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return nil }
            extractCookies(from: http)

            let html = String(data: data, encoding: .utf8) ?? ""
            let looksLoggedIn = http.statusCode == 200
                && !html.contains("cas/login")
                && !html.contains("统一身份认证")
                && !html.contains("name=\"execution\"")

            if looksLoggedIn
            {
                saveCachedCookies(username: username)
                print("✅ 复用教务 Cookie 成功")
                return "JSESSIONID=\(cookieJar["JSESSIONID"] ?? jsessionId)"
            }
        }
        catch
        {
            print("⚠️ 教务 Cookie 探测失败: \(error.localizedDescription)")
        }

        return nil
    }

    private func finishLoginWithTicketLocation(_ location: String, username: String) async throws -> String
    {
        print("🔐 获取教务 Ticket")
        let httpsLocation = location.replacingOccurrences(
            of: "http://byjxyt.hzau.edu.cn",
            with: "https://byjxyt.hzau.edu.cn"
        )

        let candidates = Array(Set([location, httpsLocation])).sorted { lhs, rhs in
            lhs.hasPrefix("https://") && rhs.hasPrefix("http://")
        }

        var lastError: Error?
        for candidate in candidates
        {
            guard let url = URL(string: candidate) else { continue }
            print("🔐 尝试教务 Ticket: \(candidate)")
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(getCookieHeader(), forHTTPHeaderField: "Cookie")
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

            do
            {
                let (_, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse
                else
                {
                    throw NSError(domain: "TicketLoginFailed", code: 500)
                }

                extractCookies(from: httpResponse)

                if let jsessionId = cookieJar["JSESSIONID"]
                {
                    saveCachedCookies(username: username)
                    print("✅ 登录成功，获得并缓存教务 Cookie")
                    return "JSESSIONID=\(jsessionId)"
                }

                lastError = NSError(domain: "CookieNotFound", code: 404)
            }
            catch
            {
                lastError = error
                print("⚠️ 教务 Ticket 失败: \(error.localizedDescription)")
            }
        }

        throw lastError ?? NSError(domain: "CookieNotFound", code: 404)
    }

    private func formEncode(_ str: String) -> String
    {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.~")
        return str.addingPercentEncoding(withAllowedCharacters: allowed) ?? str
    }

    private func performMFAIfNeeded(username: String, password: String, mfaCodeProvider: MFACodeProvider?) async throws -> String
    {
        if CASMFADebug.forcePromptEnabled
        {
            guard let provider = mfaCodeProvider else
            {
                throw CASMFAError.needCodeInput
            }
            let code = await MFACodeContext.requestCode(
                using: provider,
                maskedPhone: CASMFADebug.maskedPhone,
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
            "fpVisitorId=\(formEncode(CASMFADebug.fpVisitorId))",
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
        print("[MFA][Schedule] detect need=\(detectInfo.need), securePhone=\(detectInfo.mfaTypeSecurePhone ?? false), state=\(detectInfo.state ?? "nil"), fpVisitorId=\(CASMFADebug.fpVisitorId)")
        guard detectInfo.need else
        {
            print("[MFA][Schedule] 服务端判定无需二次验证，本次不会弹验证码。")
            return ""
        }
        guard (detectInfo.mfaTypeSecurePhone ?? false) else
        {
            throw CASMFAError.unsupportedType
        }
        guard let state = detectInfo.state, !state.isEmpty else
        {
            throw CASMFAError.initFailed
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
        loadCachedCookies(username: username)
        if let cachedCookie = await cachedAcademicCookieIfValid(username: username)
        {
            return cachedCookie
        }

        // Step 1: GET 获取 Execution
        print("🔐 Step 1: 获取登录页面")
        var request1 = URLRequest(url: URL(string: step1And2URL)!)
        request1.httpMethod = "GET"
        request1.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request1.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request1.setValue("zh-CN,zh;q=0.9", forHTTPHeaderField: "Accept-Language")
        let cachedHeader = getCookieHeader()
        if !cachedHeader.isEmpty
        {
            request1.setValue(cachedHeader, forHTTPHeaderField: "Cookie")
        }
        
        let (data1, response1) = try await session.data(for: request1)
        guard let httpResponse1 = response1 as? HTTPURLResponse
        else
        {
            throw NSError(domain: "Step1Failed", code: 500)
        }
        
        extractCookies(from: httpResponse1)
        saveCASCookiesIfAvailable(username: username)

        if let location = httpResponse1.allHeaderFields["Location"] as? String
        {
            print("✨ 复用 CAS 登录态换取教务 Cookie")
            return try await finishLoginWithTicketLocation(location, username: username)
        }

        let html = String(data: data1, encoding: .utf8) ?? ""
        
        // 提取 execution
        guard let range = html.range(of: #"name="execution"\s+value="([^"]+)""#, options: .regularExpression)
        else
        {
            if !cachedHeader.isEmpty
            {
                print("⚠️ CAS 页面未找到 execution，清除旧 Cookie 后重试")
                clearCachedCookies(username: username)
                return try await loginAndGetCookie(username: username, rsaPassword: rsaPassword, mfaCodeProvider: mfaCodeProvider)
            }

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
        
        let cookieHeader = getCookieHeader()
        if !cookieHeader.isEmpty
        {
            request2.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }
        
        let mfaState = try await performMFAIfNeeded(username: username, password: rsaPassword, mfaCodeProvider: mfaCodeProvider)
        
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
            "fpVisitorId=\(formEncode(CASMFADebug.fpVisitorId))",
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
        saveCASCookiesIfAvailable(username: username)
        
        return try await finishLoginWithTicketLocation(location3, username: username)
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
