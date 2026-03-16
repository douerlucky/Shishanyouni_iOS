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
    private let courseQueryURL = "http://byjxyt.hzau.edu.cn/kbcx/xskbcx_cxXsKb.html?gnmkdm=N2151"
    
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
        if let setCookies = response.allHeaderFields["Set-Cookie"] as? String
        {
            let cookies = setCookies.components(separatedBy: ",")
            for cookie in cookies
            {
                if let nameValuePair = cookie.components(separatedBy: ";").first
                {
                    let parts = nameValuePair.trimmingCharacters(in: .whitespaces).components(separatedBy: "=")
                    if parts.count == 2
                    {
                        cookieJar[parts[0]] = parts[1]
                        print("保存Cookie: \(parts[0])=\(parts[1].prefix(20))...")
                    }
                }
            }
        }
    }
    
    private func getCookieHeader() -> String
    {
        return cookieJar.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
    }
    
    // MARK: - 登录获取Cookie
    
    func loginAndGetCookie(username: String, rsaPassword: String) async throws -> String
    {
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
        let html = String(data: data1, encoding: .utf8) ?? ""
        
        // 提取 execution
        guard let range = html.range(of: #"name="execution"\s+value="([^"]+)""#, options: .regularExpression)
        else
        {
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
        
        func formEncode(_ str: String) -> String
        {
            var allowed = CharacterSet.alphanumerics
            allowed.insert(charactersIn: "-_.~")
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
        
        // Step 3: GET Ticket 链接
        print("🔐 Step 3: 获取Ticket")
        var request3 = URLRequest(url: URL(string: location3)!)
        request3.httpMethod = "GET"
        request3.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        let (_, response3) = try await session.data(for: request3)
        guard let httpResponse3 = response3 as? HTTPURLResponse
        else
        {
            throw NSError(domain: "Step3Failed", code: 500)
        }
        
        extractCookies(from: httpResponse3)
        
        // 从 cookieJar 中提取 JSESSIONID
        if let jsessionId = cookieJar["JSESSIONID"]
        {
            let cookie = "JSESSIONID=\(jsessionId)"
            print("✅ 登录成功，获得Cookie")
            return cookie
        }
        
        throw NSError(domain: "CookieNotFound", code: 404)
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
