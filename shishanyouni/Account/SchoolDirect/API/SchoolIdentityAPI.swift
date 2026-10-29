// 学校统一身份认证登录及验证码请求。

import Foundation

/// 只负责学校 CAS 登录校验和短信 MFA 流程。
class SchoolIdentityAPI: NSObject, URLSessionTaskDelegate {

    private let sessionConfiguration: URLSessionConfiguration

    init(sessionConfiguration: URLSessionConfiguration = .ephemeral) {
        self.sessionConfiguration = sessionConfiguration
        super.init()
    }
    
    // 手动存储 cookies
    private var cookieJar: [String: String] = [:]
    
    private lazy var session: URLSession = {
        let config = sessionConfiguration
        // 禁用自动 cookie 管理，改为手动
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    // 禁用自动重定向
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
    
    // 手动提取和存储 cookies
    private func extractCookies(from response: HTTPURLResponse) {
        let headerFields = response.allHeaderFields.reduce(into: [String: String]()) { partialResult, item in
            if let key = item.key as? String, let value = item.value as? String {
                partialResult[key] = value
            }
        }
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: response.url ?? URL(string: SchoolDirectAPI.casPortalLoginURL)!)
        for cookie in cookies {
            cookieJar[cookie.name] = cookie.value
            print("保存 Cookie: \(cookie.name)")
        }
    }
    
    // 手动构建 Cookie header
    private func getCookieHeader() -> String {
        return cookieJar.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
    }

    private func formEncode(_ str: String) -> String {
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
        detectRequest.setValue(SchoolDirectAPI.casPortalLoginURL, forHTTPHeaderField: "Referer")
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
        print("[MFA][Login] detect need=\(detectInfo.need), securePhone=\(detectInfo.mfaTypeSecurePhone ?? false)")
        // state 是本次登录检测凭证；免短信验证也必须随表单提交。
        guard let state = detectInfo.state, !state.isEmpty else {
            throw CASMFAError.initFailed
        }
        guard detectInfo.need else {
            print("[MFA][Login] 无需短信验证，保留检测凭证继续登录。")
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
    
    /// 校验 CAS 账号密码；如服务端要求短信验证，会通过 `mfaCodeProvider` 弹出验证码输入。
    func bind(username: String, password: String, mfaCodeProvider: MFACodeProvider? = nil) async throws -> CASBindResult {
        // 清空之前的 cookies
        cookieJar.removeAll()
        
        // ===== Step 1: GET 获取 Execution =====
        print("Step 1: GET 获取 Execution")
        print("URL: \(SchoolDirectAPI.casPortalLoginURL)")
        
        var request1 = URLRequest(url: URL(string: SchoolDirectAPI.casPortalLoginURL)!)
        request1.httpMethod = "GET"
        request1.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request1.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request1.setValue("zh-CN,zh;q=0.9", forHTTPHeaderField: "Accept-Language")
        
        let (data1, response1) = try await session.data(for: request1)
        guard let httpResponse1 = response1 as? HTTPURLResponse else {
            throw NSError(domain: "Step1Failed", code: 500)
        }
        print("Status: \(httpResponse1.statusCode)")
        
        // 手动提取 cookies
        print("Step 1 提取 Cookies:")
        extractCookies(from: httpResponse1)
        
        let html = String(data: data1, encoding: .utf8) ?? ""
        
        // 提取 execution
        guard let range = html.range(of: #"name="execution"\s+value="([^"]+)""#, options: .regularExpression) else {
            print("未找到 execution")
            throw NSError(domain: "ExecutionNotFound", code: 404)
        }
        
        let matchedText = String(html[range])
        guard let valueStart = matchedText.range(of: "value=\""),
              let valueEnd = matchedText.range(of: "\"", range: valueStart.upperBound..<matchedText.endIndex) else {
            throw NSError(domain: "ExecutionParseError", code: 404)
        }
        
        let execution = String(matchedText[valueStart.upperBound..<valueEnd.lowerBound])
        print("已取得登录页面 execution。")
        
        // ===== Step 2: POST 提交表单 =====
        print("\nStep 2: POST 提交表单")
        print("URL: \(SchoolDirectAPI.casPortalLoginURL)")
        
        var request2 = URLRequest(url: URL(string: SchoolDirectAPI.casPortalLoginURL)!)
        request2.httpMethod = "POST"
        request2.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request2.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request2.setValue(SchoolDirectAPI.casPortalLoginURL, forHTTPHeaderField: "Referer")
        request2.setValue(SchoolDirectAPI.casOrigin, forHTTPHeaderField: "Origin")
        
        let mfaState = try await performMFAIfNeeded(username: username, password: password, mfaCodeProvider: mfaCodeProvider)

        // MFA 检测/验证可能更新会话，最终提交使用最新 Cookie。
        let cookieHeader = getCookieHeader()
        if !cookieHeader.isEmpty {
            request2.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
            print("已附加 \(cookieJar.count) 个 Cookie。")
        } else {
            print("警告：没有 cookies 可发送")
        }
        
        let bodyString = [
            "username=\(formEncode(username))",
            "password=\(formEncode(password))",
            "captcha=",
            "execution=\(formEncode(execution))",
            "_eventId=submit",
            "currentMenu=1",
            "failN=0",
            "mfaState=\(formEncode(mfaState))",
            "geolocation=",
            "submit1=Login1",
            "fpVisitorId=\(formEncode(CASClientEnvironment.fpVisitorId))"
        ].joined(separator: "&")
        
        request2.httpBody = bodyString.data(using: .utf8)
        
        let (data2, response2) = try await session.data(for: request2)
        guard let httpResponse2 = response2 as? HTTPURLResponse else {
            throw NSError(domain: "Step2Failed", code: 500)
        }
        print("Status: \(httpResponse2.statusCode)")
        
        extractCookies(from: httpResponse2)

        // CAS 失败时仍返回登录页（HTTP 200），不能直接判定为密码错误。
        if httpResponse2.statusCode == 200 {
            print("CAS 返回登录页，响应体大小: \(data2.count) 字节。")
            return .failure(message: CASLoginFailure.message(from: data2))
        } else if httpResponse2.statusCode == 302 {
            // 302 表示登录成功
            print("登录成功！")
            
            if httpResponse2.allHeaderFields["Location"] != nil {
                print("登录成功，已收到服务端跳转。")
            }
            return .success
        } else {
            // 其他状态码
            return .failure(message: "未知错误，状态码: \(httpResponse2.statusCode)")
        }
    }
}
