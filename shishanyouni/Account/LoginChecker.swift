//
//  LoginChecker.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/9.
//

import Foundation

/// 狮山有你后端绑定接口返回结构。
struct ShishanyouniBindResponse {
    let msg: String? //返回处理消息(失败时返回对应错误信息)
    let code: Int? //响应编码(200是成功，其它都是失败)
    let data: ShishanyouniBindData? //需要短信验证码时包含手机号和 sessionId
    let success: Bool? // v1 绑定的成功标志

    init(json: [String: Any])
    {
        msg = json["msg"] as? String
        code = Self.intValue(from: json["code"])
        success = json["success"] as? Bool

        if let dataJSON = json["data"] as? [String: Any]
        {
            data = ShishanyouniBindData(json: dataJSON)
        }
        else
        {
            data = nil
        }
    }

    static func intValue(from value: Any?) -> Int?
    {
        if let intValue = value as? Int
        {
            return intValue
        }
        if let stringValue = value as? String
        {
            return Int(stringValue)
        }
        if let numberValue = value as? NSNumber
        {
            return numberValue.intValue
        }
        return nil
    }
}

/// 狮山有你绑定需要短信验证码时返回的 data。
struct ShishanyouniBindData {
    let phone: String?
    let sessionId: String?

    init(json: [String: Any])
    {
        phone = json["phone"] as? String
        sessionId = json["sessionId"] as? String
    }
}

/// 狮山有你后端绑定过程中可能出现的错误。
enum ShishanyouniBindError: LocalizedError {
    case invalidURL
    case requestFailed(String)
    case invalidResponse
    case serverRejected(code: Int?, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "绑定地址无效。"
        case let .requestFailed(message):
            return message
        case .invalidResponse:
            return "狮山有你后端返回了无法识别的响应。"
        case let .serverRejected(code, message):
            if let code
            {
                return "code \(code)：\(message)"
            }
            return message
        }
    }
}

/// 只负责调用狮山有你服务器的账号绑定接口。
class ShishanyouniBinder {
    private let bindURL = "https://lion.hzau.edu.cn/app/ios/bind"
    private let sendCodeURL = "https://lion.hzau.edu.cn/app/ios/sendCode"
    private let submitCodeURL = "https://lion.hzau.edu.cn/app/ios/submitCode"

    func bind(username: String, password: String, type: Int = 0) async throws {
        guard let url = URL(string: bindURL) else {
            throw ShishanyouniBindError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "username": username,
            "password": password,
            "type": type
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            throw ShishanyouniBindError.requestFailed("狮山有你后端请求体编码失败。")
        }
        request.httpBody = bodyData

        do {
            let (data, response) = try await NetworkService.perform(request: request)

            guard let http = response as? HTTPURLResponse else {
                throw ShishanyouniBindError.invalidResponse
            }
            print("[ShishanyouniBinder] 状态码: \(http.statusCode)")

            let responseText = String(data: data, encoding: .utf8) ?? ""
            print("[ShishanyouniBinder] 响应: \(responseText.prefix(500))")

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw ShishanyouniBindError.invalidResponse
            }
            let result = ShishanyouniBindResponse(json: json)

            if result.success == true || result.code == 200 || result.code == 2 {
                print("[ShishanyouniBinder] 绑定成功: \(result.msg ?? "成功")")
                return
            } else if result.code == 22 {
                print("[ShishanyouniBinder] 需要短信验证")
                try ShishanyouniAPIError.throwIfMFAResponse(data)
                throw ShishanyouniAPIError.invalidResponse
            } else {
                let message = result.msg ?? "狮山有你后端绑定失败。"
                print("[ShishanyouniBinder] 绑定失败 (code \(result.code ?? -1)): \(message)")
                throw ShishanyouniAPIError.apiError(code: result.code, message: message)
            }
        } catch let error as ShishanyouniBindError {
            throw error
        } catch let error as ShishanyouniAPIError {
            throw error
        } catch let error as URLError {
            let message: String
            switch error.code {
            case .secureConnectionFailed, .serverCertificateHasBadDate, .serverCertificateUntrusted, .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid, .clientCertificateRejected, .clientCertificateRequired:
                message = "TLS错误导致安全连接失败。"
            default:
                message = error.localizedDescription
            }
            print("[ShishanyouniBinder] 请求异常: \(message)")
            throw ShishanyouniBindError.requestFailed(message)
        } catch {
            print("[ShishanyouniBinder] 请求异常: \(error.localizedDescription)")
            throw ShishanyouniBindError.requestFailed(error.localizedDescription)
        }
    }

    func sendCode(sessionId: String) async throws {
        var components = URLComponents(string: sendCodeURL)
        components?.queryItems = [URLQueryItem(name: "sessionId", value: sessionId)]
        guard let url = components?.url else {
            throw ShishanyouniBindError.invalidURL
        }

        let json = try await postQuery(url: url, label: "发送短信验证码")
        let response = ShishanyouniCodeResponse(json: json)
        guard response.code == 2 else {
            throw ShishanyouniBindError.serverRejected(code: response.code, message: response.msg ?? "短信验证码发送失败。")
        }
        print("[ShishanyouniBinder] 短信验证码发送成功")
    }

    func submitCode(sessionId: String, smsCode: String) async throws -> String {
        var components = URLComponents(string: submitCodeURL)
        components?.queryItems = [
            URLQueryItem(name: "sessionId", value: sessionId),
            URLQueryItem(name: "smsCode", value: smsCode)
        ]
        guard let url = components?.url else {
            throw ShishanyouniBindError.invalidURL
        }

        let json = try await postQuery(url: url, label: "提交短信验证码")
        let response = ShishanyouniCodeResponse(json: json)
        guard let token = response.data, !token.isEmpty,
              response.code == 0 || response.code == 2 || response.code == 200
        else {
            throw ShishanyouniBindError.serverRejected(code: response.code, message: response.msg ?? "短信验证码校验失败。")
        }
        print("[ShishanyouniBinder] 短信验证码校验成功，已获取 token")
        return token
    }

    private func postQuery(url: URL, label: String) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (data, response) = try await NetworkService.perform(request: request, timeout: 120)
        guard let http = response as? HTTPURLResponse else {
            throw ShishanyouniBindError.invalidResponse
        }
        print("[ShishanyouniBinder] \(label)状态码: \(http.statusCode)")
        let responseText = String(data: data, encoding: .utf8) ?? ""
        print("[ShishanyouniBinder] \(label)响应: \(responseText.prefix(500))")

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ShishanyouniBindError.invalidResponse
        }
        return json
    }
}

struct ShishanyouniCodeResponse {
    let msg: String?
    let code: Int?
    let data: String?

    init(json: [String: Any])
    {
        msg = json["msg"] as? String
        code = ShishanyouniBindResponse.intValue(from: json["code"])
        data = json["data"] as? String
    }
}

enum CASBindResult {
    case success
    case failure(message: String)
}

/// 只负责学校 CAS 登录校验和短信 MFA 流程。
class CASBinder: NSObject, URLSessionTaskDelegate {
    private let loginURL = "https://cas-paas.hzau.edu.cn/cas/login?service=https://portal-paas.hzau.edu.cn/"
    private let mfaDetectURL = "https://cas-paas.hzau.edu.cn/cas/mfa/detect"
    private let mfaInitSecurePhoneURL = "https://cas-paas.hzau.edu.cn/cas/mfa/initByType/securephone"
    
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
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: response.url ?? URL(string: loginURL)!)
        for cookie in cookies {
            cookieJar[cookie.name] = cookie.value
            print("保存: \(cookie.name)=\(cookie.value.prefix(20))...")
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
        if CASMFADebug.forcePromptEnabled {
            guard let provider = mfaCodeProvider else {
                throw CASMFAError.needCodeInput
            }
            let code = await MFACodeContext.requestCode(
                using: provider,
                maskedPhone: CASMFADebug.maskedPhone,
                sendCodeAction: { nil }
            )
            guard let code, !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw CASMFAError.cancelled
            }
            return ""
        }

        var detectRequest = URLRequest(url: URL(string: mfaDetectURL)!)
        detectRequest.httpMethod = "POST"
        detectRequest.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        detectRequest.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        detectRequest.setValue(getCookieHeader(), forHTTPHeaderField: "Cookie")
        detectRequest.setValue(loginURL, forHTTPHeaderField: "Referer")
        detectRequest.setValue("https://cas-paas.hzau.edu.cn", forHTTPHeaderField: "Origin")
        detectRequest.httpBody = [
            "username=\(formEncode(username))",
            "password=\(formEncode(password))",
            "fpVisitorId=\(formEncode(CASMFADebug.fpVisitorId))",
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
        print("[MFA][Login] detect need=\(detectInfo.need), securePhone=\(detectInfo.mfaTypeSecurePhone ?? false), state=\(detectInfo.state ?? "nil"), fpVisitorId=\(CASMFADebug.fpVisitorId)")
        guard detectInfo.need else {
            print("[MFA][Login] 服务端判定无需二次验证，本次不会弹验证码。")
            return ""
        }
        guard (detectInfo.mfaTypeSecurePhone ?? false) else {
            throw CASMFAError.unsupportedType
        }
        guard let state = detectInfo.state, !state.isEmpty else {
            throw CASMFAError.initFailed
        }
        guard let provider = mfaCodeProvider else {
            throw CASMFAError.needCodeInput
        }

        var initComponents = URLComponents(string: mfaInitSecurePhoneURL)!
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
                var sendRequest = URLRequest(url: URL(string: initInfo.attestServerUrl + "/api/guard/securephone/send")!)
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

        var validRequest = URLRequest(url: URL(string: initInfo.attestServerUrl + "/api/guard/securephone/valid")!)
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
        print("URL: \(loginURL)")
        
        var request1 = URLRequest(url: URL(string: loginURL)!)
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
        print("Execution: \(execution.prefix(50))...")
        
        // ===== Step 2: POST 提交表单 =====
        print("\nStep 2: POST 提交表单")
        print("URL: \(loginURL)")
        
        var request2 = URLRequest(url: URL(string: loginURL)!)
        request2.httpMethod = "POST"
        request2.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request2.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request2.setValue(loginURL, forHTTPHeaderField: "Referer")
        request2.setValue("https://cas-paas.hzau.edu.cn", forHTTPHeaderField: "Origin")
        
        // 手动添加 Cookie header
        let cookieHeader = getCookieHeader()
        if !cookieHeader.isEmpty {
            request2.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
            print("发送 Cookies: \(cookieHeader.prefix(100))...")
        } else {
            print("警告：没有 cookies 可发送")
        }
        
        let mfaState = try await performMFAIfNeeded(username: username, password: password, mfaCodeProvider: mfaCodeProvider)
        
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
            "fpVisitorId=\(formEncode(CASMFADebug.fpVisitorId))"
        ].joined(separator: "&")
        
        request2.httpBody = bodyString.data(using: .utf8)
        
        let (data2, response2) = try await session.data(for: request2)
        guard let httpResponse2 = response2 as? HTTPURLResponse else {
            throw NSError(domain: "Step2Failed", code: 500)
        }
        print("Status: \(httpResponse2.statusCode)")
        
        // 根据状态码判断登录结果
        if httpResponse2.statusCode == 200 {
            // 200 表示登录失败（账号或密码错误）
            let responseText = String(data: data2, encoding: .utf8) ?? ""
            print("登录失败，返回内容前 500 字符:")
            print(responseText.prefix(500))
            return .failure(message: "账号或密码错误")
        } else if httpResponse2.statusCode == 302 {
            // 302 表示登录成功
            print("登录成功！")
            
            if let location = httpResponse2.allHeaderFields["Location"] as? String {
                print("重定向到: \(location)")
            }
            return .success
        } else {
            // 其他状态码
            return .failure(message: "未知错误，状态码: \(httpResponse2.statusCode)")
        }
    }
}
