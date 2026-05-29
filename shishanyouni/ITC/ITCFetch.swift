import Foundation

struct ITC_Course: Identifiable
{
    let courseID: String
    let name: String

    var id: String { courseID }
}

struct ITC_Assignment: Identifiable
{
    let courseID: String
    let assignID: String
    let assignName: String
    let isCurrent: Bool
    var ddlTime: String?
    var fullGrade: String?
    var allQuestionsCount: String?
    var questionList: [ITC_Question]?

    var id: String { assignID }

    var finalScore: String
    {
        guard let list = questionList, !list.isEmpty else { return "-" }
        // 只有编程题（有评判结果/测试数据）才计入实际得分
        let programmingQuestions = list.filter { $0.isProgramming }
        guard !programmingQuestions.isEmpty else { return "-" }
        let total = programmingQuestions.reduce(0.0)
        { sum, q in
            if let g = Double(q.grade), q.grade != "-" { return sum + g }
            return sum
        }
        return String(format: "%.1f", total)
    }

    var completedCount: Int
    {
        questionList?.filter { $0.hasSubmitted }.count ?? 0
    }

    var totalQuestionCount: Int
    {
        questionList?.count ?? 0
    }
}

struct ITC_Question: Identifiable
{
    let name: String
    let sectionType: String   // 题型区块名，如"多选题"/"判断题"/"编程题"
    let questionFullGrade: String
    let firstSubmitTime: String
    let lastUpdate: String
    let grade: String
    let submittedByBadge: Bool  // <span>已提交</span> badge 方式标记
    let testData: [ITC_TestData]

    var id: String { name }

    // 编程题：有测试数据（有「评判结果」字样）才是编程题，其余题型不计得分
    var isProgramming: Bool { !testData.isEmpty }

    var hasSubmitted: Bool
    {
        if submittedByBadge { return true }
        if !grade.isEmpty && grade != "-" { return true }
        if !firstSubmitTime.isEmpty && firstSubmitTime != "-" { return true }
        if !lastUpdate.isEmpty && lastUpdate != "-" { return true }
        return false
    }

    var isReportType: Bool
    {
        !firstSubmitTime.isEmpty && firstSubmitTime != "-"
    }
}

struct ITC_TestData: Identifiable
{
    let dataID: String
    let correctStatus: String

    var id: String { dataID }

    var isCorrect: Bool { correctStatus.contains("正确") }
}

enum ITCError: LocalizedError
{
    case executionNotFound
    case loginFailed(String)
    case noLocation
    case cookieNotFound
    case parseFailed
    case networkError(String)
    case notLoggedIn

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
        case .notLoggedIn:
            return "尚未登录，请先获取课程列表完成登录。"
        }
    }
}

class ITCFetch: NSObject, URLSessionTaskDelegate
{
    static let shared = ITCFetch()

    private let casServiceURL = "https://cas-paas.hzau.edu.cn/cas/login?service=https%3A%2F%2Fitc.hzau.edu.cn%2F"
    private let courseListURL = "https://itc.hzau.edu.cn/courselist.jsp?courseID=0"
    private let baseURL = "https://itc.hzau.edu.cn"

    private var cookieJar: [String: String] = [:]

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private lazy var redirectSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        return URLSession(configuration: config)
    }()

    var isLoggedIn: Bool { cookieJar["educg_session"] != nil }

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

    private func makeRequest(_ path: String) -> URLRequest
    {
        var request = URLRequest(url: URL(string: "\(baseURL)\(path)")!)
        request.httpMethod = "GET"
        request.setValue(getCookieHeader(), forHTTPHeaderField: "Cookie")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9", forHTTPHeaderField: "Accept-Language")
        return request
    }

    // MARK: - 登录 + 获取课程列表

    func loginAndFetchCourses(username: String, rsaPassword: String) async throws -> [ITC_Course]
    {
        cookieJar = [:]

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
        var request = makeRequest("/courselist.jsp?courseID=0")
        request.setValue(casServiceURL, forHTTPHeaderField: "Referer")

        let (data, response) = try await redirectSession.data(for: request)
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
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }

        let nsRange = NSRange(html.startIndex ..< html.endIndex, in: html)
        let matches = regex.matches(in: html, options: [], range: nsRange)

        for match in matches
        {
            guard match.numberOfRanges == 3 else { continue }
            if let idR = Range(match.range(at: 1), in: html),
               let nameR = Range(match.range(at: 2), in: html)
            {
                let courseID = String(html[idR])
                let name = String(html[nameR]).trimmingCharacters(in: .whitespacesAndNewlines)
                courses.append(ITC_Course(courseID: courseID, name: name))
            }
        }
        return courses
    }

    // MARK: - 切换课程 + 获取作业列表

    func fetchAssignments(courseID: String) async throws -> (current: [ITC_Assignment], history: [ITC_Assignment])
    {
        guard isLoggedIn else { throw ITCError.notLoggedIn }

        _ = try? await session.data(for: makeRequest("/courselist.jsp?courseID=\(courseID)"))

        var request = makeRequest("/assignment/index.jsp")
        request.setValue("https://cas-paas.hzau.edu.cn/", forHTTPHeaderField: "Referer")

        let (data, response) = try await redirectSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200 ..< 300).contains(httpResponse.statusCode)
        else
        {
            throw ITCError.networkError("作业列表请求失败。")
        }

        guard let html = String(data: data, encoding: .utf8) else
        {
            throw ITCError.parseFailed
        }

        var current: [ITC_Assignment] = []
        var history: [ITC_Assignment] = []

        if let clockRange = html.range(of: "fas fa-clock"),
           let historyRange = html.range(of: "fas fa-history")
        {
            let mid = html[clockRange.lowerBound ..< historyRange.lowerBound]
            current = parseAssignmentLinks(from: String(mid), isCurrent: true, courseID: courseID)
        }

        if let historyAnchor = html.range(of: "fas fa-history")
        {
            let tail = html[historyAnchor.lowerBound...]
            history = parseAssignmentLinks(from: String(tail), isCurrent: false, courseID: courseID)
        }

        return (current, history)
    }

    private func parseAssignmentLinks(from html: String, isCurrent: Bool, courseID: String) -> [ITC_Assignment]
    {
        var assignments: [ITC_Assignment] = []
        let pattern = #"href="index\.jsp\?courseID=(\d+)&assignID=(\d+)"[^>]*>\s*([^<]+)\s*</a>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) else { return [] }

        let nsRange = NSRange(html.startIndex ..< html.endIndex, in: html)
        let matches = regex.matches(in: html, options: [], range: nsRange)

        for match in matches
        {
            guard match.numberOfRanges == 4 else { continue }
            if let cidR = Range(match.range(at: 1), in: html),
               let aidR = Range(match.range(at: 2), in: html),
               let nameR = Range(match.range(at: 3), in: html)
            {
                let cID = String(html[cidR])
                let aID = String(html[aidR])
                let name = String(html[nameR]).trimmingCharacters(in: .whitespacesAndNewlines)
                assignments.append(ITC_Assignment(
                    courseID: cID,
                    assignID: aID,
                    assignName: name,
                    isCurrent: isCurrent,
                    ddlTime: nil,
                    fullGrade: nil,
                    allQuestionsCount: nil,
                    questionList: nil
                ))
            }
        }
        return assignments
    }

    // MARK: - 获取单个作业详情

    func fetchAssignmentDetail(courseID: String, assignID: String) async throws -> (ddlTime: String?, fullGrade: String?, allQuestionsCount: String?, questionList: [ITC_Question])
    {
        guard isLoggedIn else { throw ITCError.notLoggedIn }

        var request = makeRequest("/assignment/index.jsp?courseID=\(courseID)&assignID=\(assignID)")
        request.setValue("https://cas-paas.hzau.edu.cn/", forHTTPHeaderField: "Referer")

        let (data, response) = try await redirectSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200 ..< 300).contains(httpResponse.statusCode)
        else
        {
            throw ITCError.networkError("作业详情请求失败。")
        }

        guard let html = String(data: data, encoding: .utf8) else
        {
            throw ITCError.parseFailed
        }

        let ddlTime = parseDDLTime(from: html)
        let fullGrade = parseFullGrade(from: html)
        let allQuestionsCount = parseQuestionsCount(from: html)
        let questionList = parseQuestions(from: html)

        return (ddlTime, fullGrade, allQuestionsCount, questionList)
    }

    func fetchAssignmentDetailForList(courseID: String, assignID: String) async throws -> ITC_Assignment
    {
        let detail = try await fetchAssignmentDetail(courseID: courseID, assignID: assignID)
        return ITC_Assignment(
            courseID: courseID,
            assignID: assignID,
            assignName: "",
            isCurrent: false,
            ddlTime: detail.ddlTime,
            fullGrade: detail.fullGrade,
            allQuestionsCount: detail.allQuestionsCount,
            questionList: detail.questionList
        )
    }

    // MARK: - HTML 解析方法

    private func parseDDLTime(from html: String) -> String?
    {
        let pattern = #"作业时间：<b>[^<]*</b>\s*至\s*<b>([^<]+)</b>"#
        return firstMatch(pattern: pattern, in: html, group: 1)
    }

    private func parseFullGrade(from html: String) -> String?
    {
        let pattern = #"作业满分：<u><strong>\s*([\d.]+)\s*</strong></u>"#
        return firstMatch(pattern: pattern, in: html, group: 1)
    }

    private func parseQuestionsCount(from html: String) -> String?
    {
        let pattern = #"共\s*<u><strong>\s*(\d+)道"#
        return firstMatch(pattern: pattern, in: html, group: 1)
    }

    // MARK: - 题目解析主入口
    // 策略：先按题型区块 <div id="indexProsByKindDIVxxx"> 切割，
    // 每个区块内再按 <th>N.</th> 切出单题 rowHTML，避免不同区块题号重复导致错位。
    private func parseQuestions(from html: String) -> [ITC_Question]
    {
        guard !html.isEmpty else { return [] }

        // 0. 截掉页面底部无关内容（弹窗、footer、script 等），避免误匹配"关闭"等按钮文字
        //    以第一个 <div class="add-style-modal" 为截止点
        let cleanHTML: String
        if let cutRange = html.range(of: #"<div[^>]+add-style-modal"#,
                                     options: .regularExpression)
        {
            cleanHTML = String(html[html.startIndex ..< cutRange.lowerBound])
        }
        else
        {
            cleanHTML = html
        }

        // 1. 找出所有题型区块的起止位置（用 Range<String.Index> 而非 NSRange.location 做字符偏移）
        let blockPattern = #"<div\s+id="indexProsByKindDIV\d+"[^>]*>"#
        guard let blockRegex = try? NSRegularExpression(pattern: blockPattern, options: []) else { return [] }
        let fullRange = NSRange(cleanHTML.startIndex ..< cleanHTML.endIndex, in: cleanHTML)
        let blockMatches = blockRegex.matches(in: cleanHTML, options: [], range: fullRange)

        var questions: [ITC_Question] = []

        for (bi, blockMatch) in blockMatches.enumerated()
        {
            // 使用 Range<String.Index> 正确处理多字节字符
            guard let blockStartRange = Range(blockMatch.range, in: cleanHTML) else { continue }
            let blockStartIdx = blockStartRange.lowerBound
            let blockEndIdx: String.Index
            if bi + 1 < blockMatches.count,
               let nextRange = Range(blockMatches[bi + 1].range, in: cleanHTML)
            {
                blockEndIdx = nextRange.lowerBound
            }
            else
            {
                blockEndIdx = cleanHTML.endIndex
            }
            let blockHTML = String(cleanHTML[blockStartIdx ..< blockEndIdx])

            // 2. 提取本区块的题型名称，如"多选题"/"判断题"/"编程题"
            let sectionType = firstMatch(
                pattern: #"<b>\s*([^<]+)</b>"#, in: blockHTML, group: 1
            )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            // 3. 在本区块内找所有题号 <th>
            let thPattern = #"<th[^>]*>\d+\.</th>"#
            guard let thRegex = try? NSRegularExpression(pattern: thPattern, options: []) else { continue }
            let blockNSRange = NSRange(blockHTML.startIndex ..< blockHTML.endIndex, in: blockHTML)
            let thMatches = thRegex.matches(in: blockHTML, options: [], range: blockNSRange)

            for (qi, thMatch) in thMatches.enumerated()
            {
                guard let rowStartRange = Range(thMatch.range, in: blockHTML) else { continue }
                let rowStartIdx = rowStartRange.lowerBound
                let rowEndIdx: String.Index
                if qi + 1 < thMatches.count,
                   let nextThRange = Range(thMatches[qi + 1].range, in: blockHTML)
                {
                    rowEndIdx = nextThRange.lowerBound
                }
                else
                {
                    rowEndIdx = blockHTML.endIndex
                }
                let rowHTML = String(blockHTML[rowStartIdx ..< rowEndIdx])

                if let q = parseOneQuestion(from: rowHTML, sectionType: sectionType)
                {
                    print("[ITC解析] 区块\(bi+1)(\(sectionType)) 题\(qi+1): \(q.name) | 已提交:\(q.hasSubmitted) | 最后提交:\(q.lastUpdate) | 得分:\(q.grade)")
                    questions.append(q)
                }
                else
                {
                    // 详细调试：逐步输出每种提取方式的结果
                    let d1 = firstMatch(pattern: #"openAILeftFrame[^>]*>\s*([^<]+)"#, in: rowHTML, group: 1)
                    let d2 = firstMatch(pattern: #"<a\s+href="[^"]*"[^>]*>\s*([^<]+)</a>"#, in: rowHTML, group: 1)
                    let d3 = firstMatch(pattern: #"<p[^>]*>\s*([^<\n\r]{2,})"#, in: rowHTML, group: 1)
                    let d4 = firstMatch(pattern: #"<p[^>]*>([\s\S]+?)</p>"#, in: rowHTML, group: 1)
                    print("[ITC解析失败] 区块\(bi+1)(\(sectionType)) 题\(qi+1) | 方式1:\(d1 ?? "nil") | 方式2:\(d2 ?? "nil") | 方式3:\(d3?.prefix(30) ?? "nil") | 方式4:\(d4?.prefix(30) ?? "nil")")
                    print("[ITC解析失败] rowHTML前300字符: \(rowHTML.prefix(300))")
                }
            }
        }

        print("[ITC解析] 共解析到 \(questions.count) 道题")
        return questions
    }

    // 从单题 rowHTML 中提取各字段
    private func parseOneQuestion(from rowHTML: String, sectionType: String = "") -> ITC_Question?
    {
        // ---- 题目名（按优先级尝试多种方式，每种方式必须提取到非空结果才停止） ----
        var questionName: String = ""

        // 方式1：openAILeftFrame 链接文字（简答题、文件上传题等）
        if let m = firstMatch(pattern: #"openAILeftFrame[^>]*>\s*([^<]+)"#, in: rowHTML, group: 1)
        {
            questionName = m.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // 方式2：普通 <a href> 链接文字（文件上传题 fileUploadList.jsp 等）
        if questionName.isEmpty,
           let m = firstMatch(pattern: #"<a\s+href="[^"]*"[^>]*>\s*([^<]+)</a>"#, in: rowHTML, group: 1)
        {
            questionName = m.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // 方式3：<p> 开头是纯文本（如 `<p>题目文字<input...>`）
        if questionName.isEmpty,
           let m = firstMatch(pattern: #"<p[^>]*>\s*([^<\n\r]{2,})"#, in: rowHTML, group: 1)
        {
            questionName = m.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // 方式4：<p> 开头是 <span>（多选题常见），剥离所有 HTML 标签取纯文本
        if questionName.isEmpty,
           let rawP = firstMatch(pattern: #"<p[^>]*>([\s\S]+?)</p>"#, in: rowHTML, group: 1)
        {
            // 去掉 HTML 标签、<input ...> 整段、多余空白
            var text = rawP
            // 先移除 <input ...> 整段（含属性值中可能有 > 前先移除 value）
            text = text.replacingOccurrences(of: #"<input[^>]*>"#, with: " ", options: .regularExpression)
            // 再移除剩余所有 HTML 标签
            text = text.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            // 解码常见 HTML 实体
            text = text
                .replacingOccurrences(of: "&nbsp;", with: " ")
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&#39;", with: "'")
            // 折叠多余空白、去掉选项行（以 "A." "B." 等开头的行），取第一段有效文字
            let lines = text.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            // 若第一行就是选项（"A."/"B."开头），跳过
            let candidate = lines.first { !$0.hasPrefix("A.") && !$0.hasPrefix("B.") && !$0.hasPrefix("C.") && !$0.hasPrefix("D.") } ?? lines.first ?? ""
            questionName = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // 统一清理题名中的 HTML 实体残留
        questionName = decodeHTMLEntities(questionName)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !questionName.isEmpty else { return nil }

        // ---- 分值 ----
        let fullGrade = firstMatch(pattern: #"<td>([\d.]+)</td>"#, in: rowHTML, group: 1) ?? "-"

        // ---- 最后提交时间（多种写法） ----
        let lastUpdate: String
        if let m = firstMatch(pattern: #"最近一次提交时间:\s*([^<&\n\r]+)"#, in: rowHTML, group: 1)        { lastUpdate = m.trimmingCharacters(in: .whitespaces) }
        else if let m = firstMatch(pattern: #"最后一次提交时间:\s*([^<&\n\r]+)"#, in: rowHTML, group: 1)   { lastUpdate = m.trimmingCharacters(in: .whitespaces) }
        else if let m = firstMatch(pattern: #"最后一次修改时间:\s*([^<&\n\r]+)"#, in: rowHTML, group: 1)   { lastUpdate = m.trimmingCharacters(in: .whitespaces) }
        else { lastUpdate = "-" }

        // ---- 首次提交时间 ----
        let firstSubmitTime: String
        if let m = firstMatch(pattern: #"初次提交时间:\s*([^<&\n\r]+)"#, in: rowHTML, group: 1)           { firstSubmitTime = m.trimmingCharacters(in: .whitespaces) }
        else if let m = firstMatch(pattern: #"首次提交时间:\s*([^<&\n\r]+)"#, in: rowHTML, group: 1)      { firstSubmitTime = m.trimmingCharacters(in: .whitespaces) }
        else { firstSubmitTime = "-" }

        // ---- 是否已提交（badge 方式：判断题/多选题有 <span>已提交</span>） ----
        let submittedByBadge = rowHTML.contains("badge-success") && rowHTML.contains("已提交")

        // ---- 得分（仅编程题/程序片段题） ----
        let grade = firstMatch(pattern: #"得分：([\d.]+)"#, in: rowHTML, group: 1) ?? "-"

        // ---- 测试数据（编程题） ----
        let testData = parseTestData(from: rowHTML)

        return ITC_Question(
            name: questionName,
            sectionType: sectionType,
            questionFullGrade: fullGrade,
            firstSubmitTime: firstSubmitTime,
            lastUpdate: lastUpdate,
            grade: grade,
            submittedByBadge: submittedByBadge,
            testData: testData
        )
    }

    private func parseTestData(from snippet: String) -> [ITC_TestData]
    {
        var results: [ITC_TestData] = []
        let pattern = #"<tr><td>(测试数据\d+)</td><td>([^<]+)</td></tr>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }

        let nsRange = NSRange(snippet.startIndex ..< snippet.endIndex, in: snippet)
        let matches = regex.matches(in: snippet, options: [], range: nsRange)

        for match in matches
        {
            guard match.numberOfRanges == 3,
                  let idR = Range(match.range(at: 1), in: snippet),
                  let statusR = Range(match.range(at: 2), in: snippet)
            else { continue }

            results.append(ITC_TestData(
                dataID: String(snippet[idR]),
                correctStatus: String(snippet[statusR]).trimmingCharacters(in: .whitespaces)
            ))
        }
        return results
    }

    private func decodeHTMLEntities(_ text: String) -> String
    {
        text
            .replacingOccurrences(of: "&nbsp;",  with: " ")
            .replacingOccurrences(of: "&amp;",   with: "&")
            .replacingOccurrences(of: "&lt;",    with: "<")
            .replacingOccurrences(of: "&gt;",    with: ">")
            .replacingOccurrences(of: "&quot;",  with: "\"")
            .replacingOccurrences(of: "&#39;",   with: "'")
            .replacingOccurrences(of: "&#34;",   with: "\"")
            // 折叠多余空白
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
    }

    private func firstMatch(pattern: String, in html: String, group: Int) -> String?
    {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: html, options: [], range: NSRange(html.startIndex ..< html.endIndex, in: html)),
              let r = Range(match.range(at: group), in: html)
        else { return nil }
        return String(html[r]).trimmingCharacters(in: .whitespaces)
    }
}
