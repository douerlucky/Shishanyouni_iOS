import Foundation

class GymCloudAPI: NSObject, URLSessionTaskDelegate
{
    // 手动存储 cookies (用于登录过程中的状态追踪)
    private var cookieJar: [String: String] = [:]

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    // 禁止自动重定向
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest: URLRequest, completionHandler: @escaping (URLRequest?) -> Void)
    {
        completionHandler(nil)
    }

    private func extractCookies(from response: HTTPURLResponse)
    {
        let headerFields = response.allHeaderFields.reduce(into: [String: String]()) { partialResult, item in
            if let key = item.key as? String, let value = item.value as? String {
                partialResult[key] = value
            }
        }
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: response.url ?? URL(string: SchoolDirectAPI.casGymLoginURL)!)
        for cookie in cookies {
            cookieJar[cookie.name] = cookie.value
            print("[Cookie] 更新: \(cookie.name)")
        }
    }

    private func getCookieHeader() -> String
    {
        return cookieJar.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
    }

    private func finishGymLoginWithTicketLocation(_ location: String) async throws -> String
    {
        print("Step 3: GET Ticket 链接")
        var request3 = URLRequest(url: URL(string: location)!)
        request3.httpMethod = "GET"
        request3.setValue(getCookieHeader(), forHTTPHeaderField: "Cookie")

        let (_, response3) = try await session.data(for: request3)
        guard let httpResponse3 = response3 as? HTTPURLResponse,
              let finalLocation = httpResponse3.allHeaderFields["Location"] as? String
        else
        {
            throw NSError(domain: "Step3Failed", code: 500)
        }
        extractCookies(from: httpResponse3)

        print("Step 4: GET 最终地址获取 PHPSESSID & userKey")
        var request4 = URLRequest(url: URL(string: finalLocation)!)
        request4.httpMethod = "GET"
        request4.setValue(getCookieHeader(), forHTTPHeaderField: "Cookie")

        let (_, response4) = try await session.data(for: request4)
        guard let httpResponse4 = response4 as? HTTPURLResponse else { throw NSError(domain: "Network", code: 0) }
        extractCookies(from: httpResponse4)

        if let phpSessId = cookieJar["PHPSESSID"], let userKey = cookieJar["userKey"]
        {
            return "PHPSESSID=\(phpSessId); userKey=\(userKey)"
        }

        throw NSError(domain: "CookieNotFound", code: 404)
    }

    private func formEncode(_ str: String) -> String
    {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.~")
        return str.addingPercentEncoding(withAllowedCharacters: allowed) ?? str
    }

    private func performMFAIfNeeded(username: String, password: String, mfaCodeProvider: MFACodeProvider?) async throws -> String {
        // Debug 模式可强制触发验证码输入弹窗，便于本地联调 UI 流程
        if CASClientEnvironment.forcePromptEnabled {
            guard let provider = mfaCodeProvider else {
                throw CASMFAError.needCodeInput
            }
            let code = await MFACodeContext.requestCode(
                using: provider,
                maskedPhone: CASClientEnvironment.maskedPhone,
                sendCodeAction: { nil }
            )
            guard let code, !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw CASMFAError.cancelled
            }
            return ""
        }

        var detectRequest = URLRequest(url: URL(string: SchoolDirectAPI.mfaDetectURL)!)
        detectRequest.httpMethod = "POST"
        detectRequest.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        detectRequest.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        detectRequest.setValue(getCookieHeader(), forHTTPHeaderField: "Cookie")
        detectRequest.setValue(SchoolDirectAPI.casGymLoginURL, forHTTPHeaderField: "Referer")
        detectRequest.setValue(SchoolDirectAPI.casOrigin, forHTTPHeaderField: "Origin")
        detectRequest.httpBody = [
            "username=\(formEncode(username))",
            "password=\(formEncode(password))",
            "fpVisitorId=\(formEncode(CASClientEnvironment.fpVisitorId))",
        ].joined(separator: "&").data(using: .utf8)

        let (detectData, detectResponse) = try await session.data(for: detectRequest)
        guard let detectHTTP = detectResponse as? HTTPURLResponse else {
            throw NSError(domain: "MFADetectFailed", code: 500)
        }
        extractCookies(from: detectHTTP)

        let detect = try JSONDecoder().decode(CASMFADetectResponse.self, from: detectData)
        guard detect.code == 0, let detectInfo = detect.data else {
            throw CASMFAError.initFailed
        }
        print("[MFA][Gym] detect need=\(detectInfo.need), securePhone=\(detectInfo.mfaTypeSecurePhone ?? false)")
        // state 是本次登录检测凭证；免短信验证也必须随表单提交。
        guard let state = detectInfo.state, !state.isEmpty else {
            throw CASMFAError.initFailed
        }
        guard detectInfo.need else {
            print("[MFA][Gym] 无需短信验证，保留检测凭证继续登录。")
            return state
        }
        guard (detectInfo.mfaTypeSecurePhone ?? false) else {
            throw CASMFAError.unsupportedType
        }
        guard let provider = mfaCodeProvider else {
            throw CASMFAError.needCodeInput
        }

        var initComponents = URLComponents(string: SchoolDirectAPI.mfaInitSecurePhoneURL)!
        initComponents.queryItems = [URLQueryItem(name: "state", value: state)]
        var initRequest = URLRequest(url: initComponents.url!)
        initRequest.httpMethod = "GET"
        initRequest.setValue(getCookieHeader(), forHTTPHeaderField: "Cookie")
        initRequest.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        let (initData, initResponse) = try await session.data(for: initRequest)
        guard let initHTTP = initResponse as? HTTPURLResponse else {
            throw NSError(domain: "MFAInitFailed", code: 500)
        }
        extractCookies(from: initHTTP)

        let initResult = try JSONDecoder().decode(CASMFAInitResponse.self, from: initData)
        guard initResult.code == 0, let initInfo = initResult.data else {
            throw CASMFAError.initFailed
        }

        let sendCodeAction: () async -> String? = {
            do
            {
                var sendRequest = URLRequest(url: URL(string: initInfo.attestServerUrl + SchoolDirectAPI.securePhoneSendPath)!)
                sendRequest.httpMethod = "POST"
                sendRequest.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
                sendRequest.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
                sendRequest.setValue(self.getCookieHeader(), forHTTPHeaderField: "Cookie")
                sendRequest.httpBody = try JSONSerialization.data(withJSONObject: ["gid": initInfo.gid], options: [])

                let (sendData, sendResponse) = try await self.session.data(for: sendRequest)
                guard let sendHTTP = sendResponse as? HTTPURLResponse else {
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
        guard let code, !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CASMFAError.cancelled
        }

        var validRequest = URLRequest(url: URL(string: initInfo.attestServerUrl + SchoolDirectAPI.securePhoneVerifyPath)!)
        validRequest.httpMethod = "POST"
        validRequest.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        validRequest.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        validRequest.setValue(getCookieHeader(), forHTTPHeaderField: "Cookie")
        validRequest.httpBody = try JSONSerialization.data(withJSONObject: ["gid": initInfo.gid, "code": code], options: [])

        let (validData, validResponse) = try await session.data(for: validRequest)
        guard let validHTTP = validResponse as? HTTPURLResponse else {
            throw NSError(domain: "MFAValidFailed", code: 500)
        }
        extractCookies(from: validHTTP)
        let validResult = try JSONDecoder().decode(CASMFACommonResponse.self, from: validData)
        guard validResult.code == 0, validResult.data?.status == 2 else {
            throw CASMFAError.verifyFailed
        }

        return state
    }

    /// 核心逻辑：登录并获取南湖跑系统的 PHPSESSID 和 userKey
    func loginAndGetRunCookie(username: String, rsaPassword: String, mfaCodeProvider: MFACodeProvider? = nil) async throws -> String
    {
        // ===== Step 1: GET 获取 CAS 登录页面的 execution 参数 =====
        print("Step 1: 获取 CAS Execution")
        var request1 = URLRequest(url: URL(string: SchoolDirectAPI.casGymLoginURL)!)
        request1.httpMethod = "GET"
        request1.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let (data1, response1) = try await session.data(for: request1)
        guard let httpResponse1 = response1 as? HTTPURLResponse else { throw NSError(domain: "Network", code: 0) }
        extractCookies(from: httpResponse1)

        if let ticketLocation = httpResponse1.allHeaderFields["Location"] as? String
        {
            print("✨ 复用 CAS 登录态换取体育系统 Cookie")
            return try await finishGymLoginWithTicketLocation(ticketLocation)
        }

        let html = String(data: data1, encoding: .utf8) ?? ""
        guard let range = html.range(of: #"name="execution"\s+value="([^"]+)""#, options: .regularExpression),
              let valueStart = html[range].range(of: "value=\""),
              let valueEnd = html[range].range(of: "\"", range: valueStart.upperBound ..< html[range].endIndex)
        else
        {
            throw NSError(domain: "ParseError", code: 404)
        }
        let execution = String(html[range][valueStart.upperBound ..< valueEnd.lowerBound])

        // ===== Step 2: POST 提交登录表单 =====
        print("Step 2: POST CAS 登录表单")
        var request2 = URLRequest(url: URL(string: SchoolDirectAPI.casGymLoginURL)!)
        request2.httpMethod = "POST"
        request2.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request2.setValue(SchoolDirectAPI.casOrigin, forHTTPHeaderField: "Origin")
        request2.setValue(SchoolDirectAPI.casGymLoginURL, forHTTPHeaderField: "Referer")
        request2.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let mfaState = try await performMFAIfNeeded(username: username, password: rsaPassword, mfaCodeProvider: mfaCodeProvider)
        // MFA 检测/验证可能更新会话，最终提交使用最新 Cookie。
        request2.setValue(getCookieHeader(), forHTTPHeaderField: "Cookie")

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
            "fpVisitorId=\(formEncode(CASClientEnvironment.fpVisitorId))",
            "submit1=Login1",
        ].joined(separator: "&")

        request2.httpBody = bodyString.data(using: .utf8)

        let (data2, response2) = try await session.data(for: request2)
        guard let httpResponse2 = response2 as? HTTPURLResponse else { throw NSError(domain: "Network", code: 0) }
        extractCookies(from: httpResponse2)

        if httpResponse2.statusCode == 200 {
            throw CASLoginFailure.error(from: data2)
        }

        guard let ticketLocation = httpResponse2.allHeaderFields["Location"] as? String
        else
        {
            print("❌ 登录仍然失败，状态码: \(httpResponse2.statusCode)")
            throw NSError(domain: "LoginFailed", code: httpResponse2.statusCode)
        }

        return try await finishGymLoginWithTicketLocation(ticketLocation)
    }

    /// 获取并解析环湖跑分数
    func fetchRunScores(cookie: String) async throws -> [RunScore]
    {
        print("\n[Fetch] 正在获取环湖跑成绩列表...")
        var request = URLRequest(url: URL(string: SchoolDirectAPI.gymRunScoreURL)!)
        request.httpMethod = "GET"
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue(SchoolDirectAPI.gymReferer, forHTTPHeaderField: "Referer")

        let (data, _) = try await NetworkService.perform(with: session, request: request)
        guard let html = String(data: data, encoding: .utf8)
        else
        {
            throw NSError(domain: "EncodingError", code: 0)
        }

        return parseScoresFrom(html: html)
    }

    func fetchRunScoresFromShishanyouni(
        username: String, encryptedPassword: String, mfa: ShishanyouniV3MFAProvider? = nil
    ) async throws -> [RunScore]
    {
        let data = try await ShishanyouniV3Session.shared.request(
            .southlake, username: username, encryptedPassword: encryptedPassword, parameters: [:], mfa: mfa
        )
        let decoded = try JSONDecoder().decode(LionSouthlakeResponse.self, from: data)
        return (decoded.data?.items ?? []).compactMap
        { item in
            let parts = item.term.split(separator: "-", maxSplits: 2).map(String.init)
            guard parts.count == 3 else { return nil }
            return RunScore(
                schoolYear: "\(parts[0])-\(parts[1])",
                semester: parts[2],
                count: item.num
            )
        }
    }

    private func parseScoresFrom(html: String) -> [RunScore]
    {
        var scores: [RunScore] = []
        let pattern = #"<tr bgcolor='#[A-F0-9]+'>\s*<td>([\d-]+)</td>\s*<td>(\d+)</td>\s*<td><span[^>]*>([\d.]+)"#

        do
        {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(html.startIndex ..< html.endIndex, in: html)
            let matches = regex.matches(in: html, options: [], range: range)

            for match in matches
            {
                if match.numberOfRanges >= 4
                {
                    let yearRange = Range(match.range(at: 1), in: html)!
                    let termRange = Range(match.range(at: 2), in: html)!
                    let countRange = Range(match.range(at: 3), in: html)!

                    let score = RunScore(
                        schoolYear: String(html[yearRange]),
                        semester: String(html[termRange]),
                        count: String(html[countRange])
                    )
                    scores.append(score)
                }
            }
        }
        catch
        {
            print("Regex Error: \(error)")
        }
        return scores
    }

    // 获取体测成绩
    // - Parameter semesterKey: 格式如 "2024-2025_1"
    func fetchPhysicalScores(cookie: String, semesterKey: String) async throws -> PhysicalScore?
    {
        let url = "\(SchoolDirectAPI.gymPhysicalScoreURL)&year=\(semesterKey)"
        var request = URLRequest(url: URL(string: url)!)
        request.setValue(cookie, forHTTPHeaderField: "Cookie")

        let (data, _) = try await NetworkService.perform(with: session, request: request)
        guard let html = String(data: data, encoding: .utf8) else { return nil }

        return parsePhysicalScores(html: html)
    }

    private func parsePhysicalScores(html: String) -> PhysicalScore?
    {
        let year = extractValue(from: html, pattern: #"测试年度</td>\s*<td[^>]*>([^<]+)</td>"#)
        let update = extractValue(from: html, pattern: #"最后更新</td>\s*<td[^>]*>([^<]+)</td>"#)
        let score = extractValue(from: html, pattern: #"成绩</td>\s*<td[^>]*><b[^>]*>([^<]+)</b>"#)
        let grade = extractValue(from: html, pattern: #"等级</td>\s*<td[^>]*><b[^>]*>([^<]+)</b>"#)
        let gradeLevel = extractValue(from: html, pattern: #"年级</td>\s*<td>([^<]+)</td>"#)
        let className = extractValue(from: html, pattern: #"班级</td>\s*<td>([^<]+)</td>"#)
        let h = extractValue(from: html, pattern: #"身高</td>\s*<td>([^<]+)</td>"#)
        let w = extractValue(from: html, pattern: #"体重</td>\s*<td>([^<]+)</td>"#)

        if year.isEmpty { return nil }

        var physical = PhysicalScore(testYear: year, updateTime: update, totalScore: score, totalGrade: grade, gradeLevel: gradeLevel, className: className, height: h, weight: w)

        // 关键更新：支持解析 HTML 中一行两列的项目
        // 逻辑：匹配 <td style='background:#bbb;'>项目名</td> <td>成绩</td> <td>得分</td> <td>等级</td>
        let detailPattern = #"<td[^>]*style='background:#bbb;'>\s*([^<]+)\s*</td>\s*<td>\s*([^<]*)\s*</td>\s*<td>\s*([^<]*)\s*</td>\s*<td>\s*([^<]*)\s*</td>"#

        let regex = try? NSRegularExpression(pattern: detailPattern)
        let matches = regex?.matches(in: html, range: NSRange(html.startIndex..., in: html)) ?? []

        for m in matches
        {
            if m.numberOfRanges >= 5
            {
                let projectName = String(html[Range(m.range(at: 1), in: html)!]).trimmingCharacters(in: .whitespacesAndNewlines)
                // 排除一些非成绩项的干扰
                if ["项目", "测试年度", "最后更新", "成绩", "等级", "年级", "班级", "身高", "体重", "加分原因"].contains(projectName)
                {
                    continue
                }

                let d = PhysicalDetail(
                    project: projectName,
                    result: String(html[Range(m.range(at: 2), in: html)!]).trimmingCharacters(in: .whitespacesAndNewlines),
                    score: String(html[Range(m.range(at: 3), in: html)!]).trimmingCharacters(in: .whitespacesAndNewlines),
                    grade: String(html[Range(m.range(at: 4), in: html)!]).trimmingCharacters(in: .whitespacesAndNewlines)
                )

                // 如果是“加分”项目且成绩得分都为空，可以跳过，除非有具体内容
                if d.project == "加分" && d.result.isEmpty && d.score.isEmpty { continue }

                physical.details.append(d)
            }
        }

        return physical
    }

    private func extractValue(from html: String, pattern: String) -> String
    {
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        if let match = regex?.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)), match.numberOfRanges >= 2
        {
            return String(html[Range(match.range(at: 1), in: html)!]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }
}
