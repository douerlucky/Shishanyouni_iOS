import Foundation

// MARK: - 电费响应数据结构

struct ElectricityResponse: Decodable
{
    let code: Int
    let msg: String
    let data: ElectricityPageData?
}

struct ElectricityPageData: Decodable
{
    let records: [ElectricityRecord]
}

struct ElectricityRecord: Identifiable, Decodable
{
    var id: String { roomId }

    let roomId: String // 房间ID
    let roomName: String // 房间名 (如: 荟01-101)
    let accountAddress: String // 详细地址 (如: 荟01栋-101)
    let balance: String // 余额 (核心字段)
    let eleAmount: String? // 电费单价/金额相关
    let roomTypeName: String? // 房间类型 (如: 本科生)

    // 嵌套的电表详情
    let baseMeterList: [MeterDetail]?

    // 计算属性：获取最新的读数时间
    var lastUpdate: String
    {
        baseMeterList?.first?.lastReadingTime ?? "未知"
    }
}

struct MeterDetail: Decodable
{
    let meterCode: String // 电表号
    let lastReading: Double? // 最后一次抄表读数
    let lastReadingTime: String? // 抄表时间
}

// MARK: - 通用选择器模型 (用于楼栋、楼层、房间列表)

struct BuildingLevelRoomResponse: Decodable
{
    let code: Int
    let msg: String
    let data: PickerData?

    // 有些接口直接返回 data 数组，有些返回 data 对象里包含 records
    enum PickerData: Decodable
    {
        case array([PickerItem])
        case object(PageRecords)

        init(from decoder: Decoder) throws
        {
            let container = try decoder.singleValueContainer()
            if let array = try? container.decode([PickerItem].self)
            {
                self = .array(array)
            }
            else if let object = try? container.decode(PageRecords.self)
            {
                self = .object(object)
            }
            else
            {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode PickerData")
            }
        }
    }

    struct PageRecords: Decodable
    {
        let records: [PickerItem]
    }
}

struct PickerItem: Decodable, Identifiable
{
    var id: String { value }
    let label: String // 显示文本 (如: 荟01栋, 1层, 101)
    let value: String // 传参值 (如: 1770694614656974850)
}

// MARK: - 电费系统登录查询类

class ElectricityQuery: NSObject, URLSessionTaskDelegate
{
    private let ssoLoginURL = "https://cas-paas.hzau.edu.cn/cas/login?service=https%3A%2F%2Fsdgl.hzau.edu.cn%2Fapi%2Fsso%2Fmobile%2Fcallback%3FtargetUrl%3Dhttps%3A%2F%2Fsdgl.hzau.edu.cn%2Fapi%2Fsso%2Fmobile%2Fcallback"
    private let mfaDetectURL = "https://cas-paas.hzau.edu.cn/cas/mfa/detect"
    private let mfaInitSecurePhoneURL = "https://cas-paas.hzau.edu.cn/cas/mfa/initByType/securephone"

    private let apiBase = "https://sdgl.hzau.edu.cn/api/base"

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

    // MARK: - Helper Methods

    private func extractCookies(from response: HTTPURLResponse)
    {
        let headerFields = response.allHeaderFields.reduce(into: [String: String]()) { partialResult, item in
            if let key = item.key as? String, let value = item.value as? String {
                partialResult[key] = value
            }
        }
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: response.url ?? URL(string: ssoLoginURL)!)
        for cookie in cookies {
            cookieJar[cookie.name] = cookie.value
        }
    }

    private func getCookieHeader() -> String
    {
        return cookieJar.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
    }

    private func formEncode(_ str: String) -> String
    {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.~")
        return str.addingPercentEncoding(withAllowedCharacters: allowed) ?? str
    }

    private func standardHeaders(token: String) -> [String: String]
    {
        return [
            "Accept": "*/*",
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
            "Authorization": "Bearer \(token)",
            "Referer": "https://sdgl.hzau.edu.cn/mobile/pages/module/search-meter",
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
        ]
    }

    private func performMFAIfNeeded(username: String, password: String, mfaCodeProvider: MFACodeProvider?) async throws -> String {
        // Debug 模式可强制触发验证码输入弹窗，便于本地联调 UI 流程
        if CASMFADebug.forcePromptEnabled {
            guard let provider = mfaCodeProvider else {
                throw CASMFAError.needCodeInput
            }
            guard let code = await provider(CASMFADebug.maskedPhone), !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw CASMFAError.cancelled
            }
            return ""
        }

        var detectRequest = URLRequest(url: URL(string: mfaDetectURL)!)
        detectRequest.httpMethod = "POST"
        detectRequest.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        detectRequest.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        detectRequest.setValue(getCookieHeader(), forHTTPHeaderField: "Cookie")
        detectRequest.setValue(ssoLoginURL, forHTTPHeaderField: "Referer")
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
        print("[MFA][Electricity] detect need=\(detectInfo.need), securePhone=\(detectInfo.mfaTypeSecurePhone ?? false), state=\(detectInfo.state ?? "nil"), fpVisitorId=\(CASMFADebug.fpVisitorId)")
        guard detectInfo.need else {
            print("[MFA][Electricity] 服务端判定无需二次验证，本次不会弹验证码。")
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

        var sendRequest = URLRequest(url: URL(string: initInfo.attestServerUrl + "/api/guard/securephone/send")!)
        sendRequest.httpMethod = "POST"
        sendRequest.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        sendRequest.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        sendRequest.setValue(getCookieHeader(), forHTTPHeaderField: "Cookie")
        sendRequest.httpBody = try JSONSerialization.data(withJSONObject: ["gid": initInfo.gid], options: [])

        let (sendData, sendResponse) = try await session.data(for: sendRequest)
        guard let sendHTTP = sendResponse as? HTTPURLResponse else {
            throw NSError(domain: "MFASendFailed", code: 500)
        }
        extractCookies(from: sendHTTP)
        let sendResult = try JSONDecoder().decode(CASMFACommonResponse.self, from: sendData)
        guard sendResult.code == 0 else {
            throw CASMFAError.sendFailed
        }

        guard let code = await provider(initInfo.securePhone), !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
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

    // MARK: - 核心登录逻辑：获取Token

    func loginAndGetToken(username: String, rsaPassword: String, mfaCodeProvider: MFACodeProvider? = nil) async throws -> String
    {
        // --- Step 1: GET 获取 execution ---
        var request1 = URLRequest(url: URL(string: ssoLoginURL)!)
        request1.httpMethod = "GET"
        request1.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let (data1, response1) = try await session.data(for: request1)
        guard let httpResponse1 = response1 as? HTTPURLResponse else { throw NSError(domain: "Step1Failed", code: 500) }
        extractCookies(from: httpResponse1)

        let html = String(data: data1, encoding: .utf8) ?? ""
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

        let mfaState = try await performMFAIfNeeded(username: username, password: rsaPassword, mfaCodeProvider: mfaCodeProvider)

        // --- Step 2: POST 提交登录表单 ---
        var request2 = URLRequest(url: URL(string: ssoLoginURL)!)
        request2.httpMethod = "POST"
        request2.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request2.allHTTPHeaderFields = standardHeaders(token: "") // 初始化时 Token 为空
        request2.setValue(ssoLoginURL, forHTTPHeaderField: "Referer")
        request2.setValue("https://cas-paas.hzau.edu.cn", forHTTPHeaderField: "Origin")
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
            "fpVisitorId=\(formEncode(CASMFADebug.fpVisitorId))",
            "submit1=Login1",
        ].joined(separator: "&")
        request2.httpBody = bodyString.data(using: .utf8)

        let (_, response2) = try await session.data(for: request2)
        guard let httpResponse2 = response2 as? HTTPURLResponse,
              let location3 = httpResponse2.allHeaderFields["Location"] as? String
        else
        {
            throw NSError(domain: "LoginFailed_NoTicketLocation", code: 401)
        }
        extractCookies(from: httpResponse2)

        // --- Step 3: GET Ticket 链接 ---
        var request3 = URLRequest(url: URL(string: location3)!)
        request3.httpMethod = "GET"
        request3.setValue(getCookieHeader(), forHTTPHeaderField: "Cookie")

        let (_, response3) = try await session.data(for: request3)
        guard let httpResponse3 = response3 as? HTTPURLResponse,
              let location4 = httpResponse3.allHeaderFields["Location"] as? String
        else
        {
            throw NSError(domain: "Step3Failed_NoFinalLocation", code: 500)
        }

        // --- Step 4: 解析 Token ---
        guard let urlComponents = URLComponents(string: location4),
              let token = urlComponents.queryItems?.first(where: { $0.name == "token" })?.value
        else
        {
            throw NSError(domain: "TokenNotFound", code: 404)
        }

        return token
    }

    // MARK: - 第一步：获取楼栋列表 (getBuildList)

    func fetchBuildingList(token: String) async throws -> [PickerItem]
    {
        let url = "\(apiBase)/baseBuildings/getBuildList?size=999&current=1"
        var request = URLRequest(url: URL(string: url)!)
        request.allHTTPHeaderFields = standardHeaders(token: token)

        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(BuildingLevelRoomResponse.self, from: data)

        if case let .object(page) = response.data
        {
            return page.records
        }
        return []
    }

    // MARK: - 第二步：获取楼层列表 (getAllFoolNumByBuildId)

    func fetchFloorList(token: String, buildingId: String) async throws -> [PickerItem]
    {
        let url = "\(apiBase)/rooms/getAllFoolNumByBuildId?buildingId=\(buildingId)"
        var request = URLRequest(url: URL(string: url)!)
        request.allHTTPHeaderFields = standardHeaders(token: token)

        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(BuildingLevelRoomResponse.self, from: data)

        if case let .array(items) = response.data
        {
            return items
        }
        return []
    }

    // MARK: - 第三步：获取房间列表 (getRoomListByBuildIdAndFloor)

    func fetchRoomList(token: String, buildingId: String, floorNum: String) async throws -> [PickerItem]
    {
        let url = "\(apiBase)/rooms/getRoomListByBuildIdAndFloor?floorNum=\(floorNum)&buildingId=\(buildingId)"
        var request = URLRequest(url: URL(string: url)!)
        request.allHTTPHeaderFields = standardHeaders(token: token)

        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(BuildingLevelRoomResponse.self, from: data)

        if case let .array(items) = response.data
        {
            return items
        }
        return []
    }

    // MARK: - 最终步：查询电费账户信息 (selectRoomsAccountPage)

    func fetchElectricityAccount(token: String, roomId: String) async throws -> [ElectricityRecord]
    {
        let queryURL = "\(apiBase)/rooms/selectRoomsAccountPage"
        var components = URLComponents(string: queryURL)!
        components.queryItems = [
            URLQueryItem(name: "size", value: "10"),
            URLQueryItem(name: "current", value: "1"),
            URLQueryItem(name: "pageTotal", value: "100"),
            URLQueryItem(name: "roomId", value: roomId),
        ]

        var request = URLRequest(url: components.url!)
        request.allHTTPHeaderFields = standardHeaders(token: token)

        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(ElectricityResponse.self, from: data)

        if response.code == 200, let records = response.data?.records
        {
            return records
        }
        else
        {
            throw NSError(domain: "QueryFailed", code: response.code, userInfo: ["msg": response.msg])
        }
    }
}
