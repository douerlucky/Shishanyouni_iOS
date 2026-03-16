//
//  LoginChecker.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/9.
//

import Foundation

struct BindResponse: Codable {
    let msg: String
    let code: Int
    let data: String?
    let timestamp: Int64
    let fail: Bool
    let success: Bool
}

class AccountBinder {
    private let bindURL = "https://lion.hzau.edu.cn/app/ios/bind"

    func bind(username: String, password: String, type: Int = 0) async {
        guard let url = URL(string: bindURL) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "username": username,
            "password": password,
            "type": type
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return }
        request.httpBody = bodyData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let http = response as? HTTPURLResponse {
                print("[AccountBinder] 状态码: \(http.statusCode)")
            }

            let result = try JSONDecoder().decode(BindResponse.self, from: data)

            if result.success {
                print("[AccountBinder] 绑定成功: \(result.msg)")
            } else {
                // 绑定失败不影响主流程，静默处理
                print("[AccountBinder] 绑定失败 (code \(result.code)): \(result.msg)")
            }

        } catch {
            print("[AccountBinder] 请求异常: \(error.localizedDescription)")
        }
    }
}

enum LoginResult {
    case success
    case failure(message: String)
}

class LoginChecker: NSObject, URLSessionTaskDelegate {
    private let loginURL = "https://cas-paas.hzau.edu.cn/cas/login?service=https://portal-paas.hzau.edu.cn/"
    
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
        if let setCookies = response.allHeaderFields["Set-Cookie"] as? String {
            let cookies = setCookies.components(separatedBy: ",")
            for cookie in cookies {
                if let nameValuePair = cookie.components(separatedBy: ";").first {
                    let parts = nameValuePair.trimmingCharacters(in: .whitespaces).components(separatedBy: "=")
                    if parts.count == 2 {
                        cookieJar[parts[0]] = parts[1]
                        print("保存: \(parts[0])=\(parts[1].prefix(20))...")
                    }
                }
            }
        }
    }
    
    // 手动构建 Cookie header
    private func getCookieHeader() -> String {
        return cookieJar.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
    }
    
    func checkLogin(username: String, password: String) async throws -> LoginResult {
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
        
        // 使用正确的 form-urlencoded 编码方式
        func formEncode(_ str: String) -> String {
            var allowed = CharacterSet.alphanumerics
            allowed.insert(charactersIn: "-_.~")
            return str.addingPercentEncoding(withAllowedCharacters: allowed) ?? str
        }
        
        let bodyString = [
            "username=\(formEncode(username))",
            "password=\(formEncode(password))",
            "execution=\(formEncode(execution))",
            "_eventId=submit",
            "currentMenu=1",
            "failN=0",
            "submit1=Login1",
            "fpVisitorId=cf1df3e32fe5f29e9c91952fed0edc7e"
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
