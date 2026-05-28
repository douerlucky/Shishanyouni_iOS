import Foundation

struct ITC_Course: Identifiable
{
    let courseID: String
    let name: String

    var id: String { courseID }
}

enum ITCError: LocalizedError
{
    case executionNotFound
    case loginFailed(String)
    case noLocation
    case cookieNotFound
    case parseFailed
    case networkError(String)

    var errorDescription: String?
    {
        switch self
        {
        case .executionNotFound:
            return "未找到CAS执行令牌。"
        case let .loginFailed(msg):
            return msg
        case .noLocation:
            return "CAS登录后未获取到重定向地址。"
        case .cookieNotFound:
            return "未获取到Session Cookie。"
        case .parseFailed:
            return "课程列表解析失败。"
        case let .networkError(msg):
            return msg
        }
    }
}

class ITCFetch: NSObject, URLSessionTaskDelegate
{
    static let shared = ITCFetch()

    private let casServiceURL = "https://cas-paas.hzau.edu.cn/cas/login?service=https%3A%2F%2Fitc.hzau.edu.cn%2F"
    private let courseListURL = "https://itc.hzau.edu.cn/courselist.jsp?courseID=0"

    private var cookieJar: [String: String] = [:]

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest: URLRequest, completionHandler: @escaping (URLRequest?) -> Void)
    {
        completionHandler(nil)
    }

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
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: response.url ?? URL(string: casServiceURL)!)
        for cookie in cookies
        {
            cookieJar[cookie.name] = cookie.value
        }
    }

    private func getCookieHeader() -> String
    {
        cookieJar.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
    }

    private func formEncode(_ str: String) -> String
    {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.~")
        return str.addingPercentEncoding(withAllowedCharacters: allowed) ?? str
    }

    func loginAndFetchCourses(username: String, rsaPassword: String) async throws -> [ITC_Course]
    {
        cookieJar = [:]

        // Step 1: GET CAS login page → get execution
        var request1 = URLRequest(url: URL(string: casServiceURL)!)
        request1.httpMethod = "GET"
        request1.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request1.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request1.setValue("zh-CN,zh;q=0.9", forHTTPHeaderField: "Accept-Language")

        let (data1, response1) = try await session.data(for: request1)
        guard let httpResponse1 = response1 as? HTTPURLResponse else
        {
            throw ITCError.networkError("无法连接CAS服务器。")
        }
        extractCookies(from: httpResponse1)

        // 如果已有CAS登录态，直接复用
        if let location = httpResponse1.allHeaderFields["Location"] as? String
        {
            return try await finishWithTicketLocation(location)
        }

        let html = String(data: data1, encoding: .utf8) ?? ""
        guard let range = html.range(of: #"name="execution"\s+value="([^"]+)""#, options: .regularExpression)
        else
        {
            throw ITCError.executionNotFound
        }
        let matchedText = String(html[range])
        guard let valueStart = matchedText.range(of: "value=\""),
              let valueEnd = matchedText.range(of: "\"", range: valueStart.upperBound ..< matchedText.endIndex)
        else
        {
            throw ITCError.executionNotFound
        }
        let execution = String(matchedText[valueStart.upperBound ..< valueEnd.lowerBound])

        // Step 2: POST login
        var request2 = URLRequest(url: URL(string: casServiceURL)!)
        request2.httpMethod = "POST"
        request2.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request2.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request2.setValue(casServiceURL, forHTTPHeaderField: "Referer")
        request2.setValue("https://cas-paas.hzau.edu.cn", forHTTPHeaderField: "Origin")

        let cookieHeader = getCookieHeader()
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
            "mfaState=",
            "execution=\(formEncode(execution))",
            "_eventId=submit",
            "geolocation=",
            "fpVisitorId=\(formEncode(CASMFADebug.fpVisitorId))",
            "submit1=Login1",
        ].joined(separator: "&")
        request2.httpBody = bodyString.data(using: .utf8)

        let (_, response2) = try await session.data(for: request2)
        guard let httpResponse2 = response2 as? HTTPURLResponse else
        {
            throw ITCError.networkError("登录请求失败。")
        }

        if httpResponse2.statusCode == 200
        {
            throw ITCError.loginFailed("CAS登录失败，请检查账号密码。")
        }

        guard let location3 = httpResponse2.allHeaderFields["Location"] as? String
        else
        {
            throw ITCError.noLocation
        }
        extractCookies(from: httpResponse2)

        return try await finishWithTicketLocation(location3)
    }

    private func finishWithTicketLocation(_ location: String) async throws -> [ITC_Course]
    {
        guard let url = URL(string: location) else { throw ITCError.networkError("票据地址无效。") }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(getCookieHeader(), forHTTPHeaderField: "Cookie")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else
        {
            throw ITCError.networkError("票据交换失败。")
        }
        extractCookies(from: httpResponse)

        guard cookieJar["educg_session"] != nil else
        {
            throw ITCError.cookieNotFound
        }

        return try await fetchCourseList()
    }

    func fetchCourseList() async throws -> [ITC_Course]
    {
        guard let url = URL(string: courseListURL) else { throw ITCError.networkError("课程列表地址无效。") }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(getCookieHeader(), forHTTPHeaderField: "Cookie")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue(casServiceURL, forHTTPHeaderField: "Referer")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200 ..< 300).contains(httpResponse.statusCode)
        else
        {
            throw ITCError.networkError("课程列表请求失败。")
        }

        guard let html = String(data: data, encoding: .utf8) else
        {
            throw ITCError.parseFailed
        }

        return parseCourses(from: html)
    }

    private func parseCourses(from html: String) -> [ITC_Course]
    {
        var courses: [ITC_Course] = []
        let pattern = #"href="courselist\.jsp\?courseID=(\d+)"[^>]*>\s*<div[^>]*>\s*([^<]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else
        {
            return []
        }

        let nsRange = NSRange(html.startIndex ..< html.endIndex, in: html)
        let matches = regex.matches(in: html, options: [], range: nsRange)

        for match in matches
        {
            guard match.numberOfRanges == 3 else { continue }
            let idRange = match.range(at: 1)
            let nameRange = match.range(at: 2)
            if let idSwiftRange = Range(idRange, in: html),
               let nameSwiftRange = Range(nameRange, in: html)
            {
                let courseID = String(html[idSwiftRange])
                let name = String(html[nameSwiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                courses.append(ITC_Course(courseID: courseID, name: name))
            }
        }

        return courses
    }
}
