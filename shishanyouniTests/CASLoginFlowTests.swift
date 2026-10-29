import Foundation
import Testing
@testable import shishanyouni

/// 全部请求由 URLProtocol 接管，不使用真实账号，也不访问学校服务器。
@Suite(.serialized)
struct CASLoginFlowTests
{
    @Test("绑定 CAS 免短信时仍提交检测凭证和最新 Cookie")
    func binderKeepsStateWithoutSMS() async throws
    {
        let binder = SchoolIdentityAPI(sessionConfiguration: installMock())
        let result = try await binder.bind(username: "cas-test-user", password: "__RSA__fixture")
        guard case .success = result else
        {
            Issue.record("免短信登录应成功")
            return
        }

        try expectFinalLoginStateAndCookie()
        #expect(CASLoginURLProtocol.requests.count == 3)
    }

    @Test("教务免短信登录保留检测凭证并换取业务 Cookie")
    func scheduleKeepsStateWithoutSMS() async throws
    {
        let query = SchoolAcademicAPI(sessionConfiguration: installMock())
        let cookie = try await query.loginAndGetCookie(username: "cas-test-user", rsaPassword: "__RSA__fixture")

        try expectFinalLoginStateAndCookie()
        #expect(cookie == "JSESSIONID=academic-session")
        let ticketRequest = try #require(CASLoginURLProtocol.requests.last)
        #expect(ticketRequest.request.url?.host == "byjxyt.hzau.edu.cn")
        #expect(ticketRequest.request.value(forHTTPHeaderField: "Cookie")?.contains("CASSESSION") != true)
        #expect(CASLoginURLProtocol.requests.count == 4)
    }

    @Test("教务独立导入只访问学校接口，开学日期固定为 2026-08-31")
    func academicImportRemainsSchoolOnly() async throws
    {
        let configuration = installMock()
        let cookie = try await SchoolAcademicAPI(sessionConfiguration: configuration)
            .loginAndGetCookie(username: "cas-test-user", rsaPassword: "__RSA__fixture")
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let result = try await AcademicCurriculumImporter.fetchCourses(
            cookie: cookie, year: "2026", term: "1", session: session
        )

        #expect(result.courses.count == 1)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let startDate = try #require(result.startDate)
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: startDate)
        #expect(components.year == 2026)
        #expect(components.month == 8)
        #expect(components.day == 31)
        #expect(components.hour == 0)

        let requests = CASLoginURLProtocol.requests
        #expect(requests.map { $0.request.url?.host } == [
            "cas-paas.hzau.edu.cn", "cas-paas.hzau.edu.cn", "cas-paas.hzau.edu.cn",
            "byjxyt.hzau.edu.cn", "byjxyt.hzau.edu.cn",
        ])
        let timetableRequest = try #require(requests.last)
        #expect(timetableRequest.request.url?.path == "/kbcx/xskbcx_cxXsKb.html")
        #expect(timetableRequest.request.value(forHTTPHeaderField: "Cookie") == "JSESSIONID=academic-session")
    }

    @Test("教务取数失败时不会回退请求狮山有你")
    func academicImportDoesNotFallBackToBackend() async throws
    {
        let session = URLSession(configuration: installMock(timetableStatus: 503))
        defer { session.invalidateAndCancel() }
        do
        {
            _ = try await AcademicCurriculumImporter.fetchCourses(
                cookie: "JSESSIONID=academic-session", year: "2026", term: "1", session: session
            )
            Issue.record("教务失败时不应返回导入成功")
        }
        catch CurriculumError.httpError(let code) { #expect(code == 503) }

        #expect(CASLoginURLProtocol.requests.map { $0.request.url?.host } == ["byjxyt.hzau.edu.cn"])
    }

    @Test("首次短信登录仍可发送验证码、完成校验后提交")
    @MainActor
    func binderPreservesSMSFlow() async throws
    {
        let configuration = installMock(needSMS: true)
        let binder = SchoolIdentityAPI(sessionConfiguration: configuration)
        let result = try await binder.bind(username: "cas-test-user", password: "__RSA__fixture")
        { phone in
            #expect(phone == "133****0000")
            guard let sendCode = MFACodeContext.activeSendCodeAction else
            {
                Issue.record("短信弹窗应提供发送验证码动作")
                return nil
            }
            let sendError = await sendCode()
            #expect(sendError == nil)
            return "123456"
        }
        guard case .success = result else
        {
            Issue.record("短信校验完成后应登录成功")
            return
        }

        try expectFinalLoginStateAndCookie()
        let requests = CASLoginURLProtocol.requests
        #expect(requests.map { $0.request.url?.path } == [
            "/cas/login", "/cas/mfa/detect", "/cas/mfa/initByType/securephone",
            "/api/guard/securephone/send", "/api/guard/securephone/valid", "/cas/login",
        ])
        let verification = try #require(requests.first { $0.request.url?.path == "/api/guard/securephone/valid" })
        let json = try #require(JSONSerialization.jsonObject(with: verification.body) as? [String: String])
        #expect(json == ["gid": "test-gid", "code": "123456"])
        let initialization = try #require(requests.first { $0.request.url?.path == "/cas/mfa/initByType/securephone" })
        let initializationURL = try #require(initialization.request.url)
        #expect(URLComponents(url: initializationURL, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "state" }?.value == "state-after-detect")
    }

    @Test("检测结果缺少 state 时终止，不继续提交登录密码")
    func missingStateStopsLogin() async throws
    {
        for useSchedule in [false, true]
        {
            let configuration = installMock(includeState: false)
            do
            {
                if useSchedule
                {
                    _ = try await SchoolAcademicAPI(sessionConfiguration: configuration)
                        .loginAndGetCookie(username: "cas-test-user", rsaPassword: "__RSA__fixture")
                }
                else
                {
                    _ = try await SchoolIdentityAPI(sessionConfiguration: configuration)
                        .bind(username: "cas-test-user", password: "__RSA__fixture")
                }
                Issue.record("缺少检测凭证时不应继续登录")
            }
            catch CASMFAError.initFailed {}
            catch { Issue.record("应返回安全验证初始化失败，实际为：\(error)") }

            #expect(CASLoginURLProtocol.requests.count == 2)
            #expect(!CASLoginURLProtocol.requests.contains { $0.isLoginSubmission })
        }
    }

    @Test("学校返回 HTTP 200 登录页时提供明确错误说明")
    func loginPageFailureHasReadableMessage() async throws
    {
        let configuration = installMock(loginStatus: 200)
        let result = try await SchoolIdentityAPI(sessionConfiguration: configuration)
            .bind(username: "cas-test-user", password: "__RSA__fixture")
        guard case let .failure(message) = result else
        {
            Issue.record("登录页响应不能当作登录成功")
            return
        }
        #expect(message.contains("安全验证状态已失效，请重新登录"))

        let query = SchoolAcademicAPI(sessionConfiguration: installMock(loginStatus: 200))
        do
        {
            _ = try await query.loginAndGetCookie(username: "cas-test-user", rsaPassword: "__RSA__fixture")
            Issue.record("登录页响应不能换取教务 Cookie")
        }
        catch
        {
            let error = error as NSError
            #expect(error.domain == "LoginFailed")
            #expect(error.code == 401)
            let message = try #require(error.userInfo[NSLocalizedDescriptionKey] as? String)
            #expect(message.contains("安全验证状态已失效，请重新登录"))
        }
    }

    private func expectFinalLoginStateAndCookie() throws
    {
        let submission = try #require(CASLoginURLProtocol.requests.first { $0.isLoginSubmission })
        #expect(submission.formValues["mfaState"] == "state-after-detect")
        #expect(submission.formValues["execution"] == "test-execution")
        #expect(submission.request.value(forHTTPHeaderField: "Cookie") == "CASSESSION=after-detect")
    }

    private func installMock(
        needSMS: Bool = false,
        includeState: Bool = true,
        loginStatus: Int = 302,
        timetableStatus: Int = 200
    ) -> URLSessionConfiguration
    {
        CASLoginURLProtocol.install
        { request in
            let method = request.httpMethod ?? "GET"
            switch (method, request.url?.path ?? "")
            {
            case ("GET", "/cas/login"):
                return .init(body: #"<input name="execution" value="test-execution">"#,
                             headers: ["Set-Cookie": "CASSESSION=before-detect; Path=/; Secure"])
            case ("POST", "/cas/mfa/detect"):
                let state = includeState ? #", "state":"state-after-detect""# : ""
                return .init(body: "{\"code\":0,\"data\":{\"need\":\(needSMS),\"mfaTypeSecurePhone\":true\(state)}}",
                             headers: ["Set-Cookie": "CASSESSION=after-detect; Path=/; Secure"])
            case ("GET", "/cas/mfa/initByType/securephone"):
                return .init(body: #"{"code":0,"data":{"gid":"test-gid","securePhone":"133****0000","attestServerUrl":"https://mfa.example.test"}}"#)
            case ("POST", "/api/guard/securephone/send"):
                return .init(body: #"{"code":0}"#)
            case ("POST", "/api/guard/securephone/valid"):
                return .init(body: #"{"code":0,"data":{"status":2}}"#)
            case ("POST", "/cas/login"):
                return .init(status: loginStatus,
                             body: #"<script>var hasErrors = true; var errors = ["安全验证状态已失效，请重新登录"];</script>"#,
                             headers: loginStatus == 302
                                ? ["Location": "http://byjxyt.hzau.edu.cn/swlogin?ticket=ST-fixture"] : [:])
            case ("GET", "/swlogin"):
                return .init(body: "Academic dashboard",
                             headers: ["Set-Cookie": "JSESSIONID=academic-session; Path=/; HttpOnly"])
            case ("POST", "/kbcx/xskbcx_cxXsKb.html"):
                return .init(status: timetableStatus,
                             body: #"{"kbList":[{"kcmc":"测试课程","xqj":"1","jcs":"1-2","zcd":"1-2周"}],"sjkList":[]}"#,
                             headers: ["Content-Type": "application/json"])
            default:
                throw NSError(domain: "UnexpectedMockRequest", code: 404)
            }
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CASLoginURLProtocol.self]
        return configuration
    }
}

private final class CASLoginURLProtocol: URLProtocol, @unchecked Sendable
{
    struct Reply
    {
        var status = 200
        var body: String
        var headers: [String: String] = [:]
    }

    struct CapturedRequest
    {
        let request: URLRequest
        let body: Data

        var isLoginSubmission: Bool { request.httpMethod == "POST" && request.url?.path == "/cas/login" }
        var formValues: [String: String]
        {
            var components = URLComponents()
            components.percentEncodedQuery = String(decoding: body, as: UTF8.self)
                .replacingOccurrences(of: "+", with: "%20")
            return (components.queryItems ?? []).reduce(into: [:]) { $0[$1.name] = $1.value }
        }
    }

    /// 只有这组串行测试使用此存储；锁保护 URLSession 回调线程与测试线程之间的访问。
    private final class Storage: @unchecked Sendable
    {
        let lock = NSLock()
        var handler: ((URLRequest) throws -> Reply)?
        var requests: [CapturedRequest] = []
    }
    private static let storage = Storage()

    static var requests: [CapturedRequest]
    {
        storage.lock.lock()
        defer { storage.lock.unlock() }
        return storage.requests
    }

    static func install(_ handler: @escaping (URLRequest) throws -> Reply)
    {
        storage.lock.lock()
        defer { storage.lock.unlock() }
        storage.requests = []
        storage.handler = handler
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading()
    {
        do
        {
            let captured = CapturedRequest(request: request, body: try requestBody())
            Self.storage.lock.lock()
            Self.storage.requests.append(captured)
            let handler = Self.storage.handler
            Self.storage.lock.unlock()
            guard let handler else { throw URLError(.resourceUnavailable) }
            let reply = try handler(request)
            guard let url = request.url,
                  let response = HTTPURLResponse(url: url, statusCode: reply.status,
                                                 httpVersion: "HTTP/1.1", headerFields: reply.headers)
            else { throw URLError(.badServerResponse) }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(reply.body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
        catch { client?.urlProtocol(self, didFailWithError: error) }
    }

    override func stopLoading() {}

    private func requestBody() throws -> Data
    {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var body = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable
        {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count < 0 { throw stream.streamError ?? URLError(.cannotDecodeRawData) }
            if count == 0 { break }
            body.append(contentsOf: buffer.prefix(count))
        }
        return body
    }
}
