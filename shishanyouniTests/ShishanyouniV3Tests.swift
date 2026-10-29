import Foundation
#if !V3_OFFLINE_TESTS
import Testing
@testable import shishanyouni

@Suite(.serialized)
struct ShishanyouniV3Tests
{
    @Test(arguments: V3TestScenario.allCases)
    func contractAndLifecycle(_ scenario: V3TestScenario) async throws
    {
        try await scenario.run()
    }
}
#endif

/// 相同场景既可在 iOS 测试包运行，也可在 macOS 独立执行，不启动模拟器。
enum V3TestScenario: String, CaseIterable, Sendable
{
    case requestContract, cachedToken, concurrentRenewal, renewalCooldown, stopRetrying
    case renewalFailure, bindMFA, businessMFA, renewalMFA, cancelMFA
    case smsCooldown, failedSMS, logoutRace, rebindRace, cancelledWaiter
    case serverMessages, otherCourses, mfaSessionLimits, logoutDuringRenewal, storageFailure

    func run() async throws
    {
        switch self
        {
        case .requestContract: try await requestContract()
        case .cachedToken: try await cachedToken()
        case .concurrentRenewal: try await concurrentRenewal()
        case .renewalCooldown: try await renewalCooldown()
        case .stopRetrying: try await stopRetrying()
        case .renewalFailure: try await renewalFailure()
        case .bindMFA: try await bindMFA()
        case .businessMFA: try await businessMFA()
        case .renewalMFA: try await renewalMFA()
        case .cancelMFA: try await cancelMFA()
        case .smsCooldown: try await smsCooldown()
        case .failedSMS: try await failedSMS()
        case .logoutRace: try await logoutRace()
        case .rebindRace: try await rebindRace()
        case .cancelledWaiter: try await cancelledWaiter()
        case .serverMessages: try await serverMessages()
        case .otherCourses: try otherCourses()
        case .mfaSessionLimits: try await mfaSessionLimits()
        case .logoutDuringRenewal: try await logoutDuringRenewal()
        case .storageFailure: try await storageFailure()
        }
    }
}

private extension V3TestScenario
{
    func requestContract() async throws
    {
        let fixture = V3Fixture { request, _ in
            try require(request.method == "POST" && request.contentType == "application/json", "必须使用 JSON POST")
            try require(request.query == nil, "不能把 sessionId 或密码放进 URL")
            switch request.endpoint
            {
            case "bind":
                try require(request.body == ["username": "test-user", "password": "mock_RSA", "type": "1"] && request.numericType, "bind 必须 RSA + 数字 type=1")
            case "sendCode": try require(request.body == ["sessionId": "sms-session"], "sendCode JSON 字段错误")
            case "submitCode": try require(request.body == ["sessionId": "sms-session", "smsCode": "123456"], "submitCode JSON 字段错误")
            case "revoke": try require(request.body == ["username": "test-user", "portalToken": "portal"], "revoke 字段错误")
            default:
                var expected = ["portalToken": "portal", request.endpoint == "score" || request.endpoint == "exam" ? "yhm" : "username": "test-user"]
                if request.endpoint != "southlake"
                {
                    expected["jwxtToken"] = "child"
                    expected[request.endpoint == "timetable" ? "year" : "xnm"] = "2026"
                    expected[request.endpoint == "timetable" ? "term" : "xqm"] = "1"
                }
                try require(request.body == expected, "业务请求包含旧密码/token/type 或字段名错误")
            }
            return .json(V3Fixture.portalJSON)
        }
        _ = try await fixture.api.bind(username: "test-user", encryptedPassword: "mock_RSA")
        _ = try await fixture.api.sendCode(sessionId: "sms-session")
        _ = try await fixture.api.submitCode(sessionId: "sms-session", code: "123456")
        try await fixture.api.revoke(username: "test-user", portalToken: "portal")
        for endpoint in [ShishanyouniV3API.Endpoint.score, .exam, .timetable, .southlake]
        {
            let parameters = endpoint == .southlake ? [:] : endpoint == .timetable ? ["year": "2026", "term": "1"] : ["xnm": "2026", "xqm": "1"]
            _ = try await fixture.api.business(endpoint, username: "test-user", credentials: .init(portalToken: "portal", jwxtToken: "child"), parameters: parameters)
        }
        try await expectFailure("查询参数")
        {
            _ = try await fixture.api.business(.score, username: "test-user", credentials: .init(portalToken: "portal"), parameters: ["password": "forbidden"])
        }
        try require(await fixture.server.count() == 8, "拒绝非法字段时不应发送请求")
    }

    func cachedToken() async throws
    {
        let fixture = V3Fixture { request, index in
            try require(request.endpoint == "score", "冷启动或已有凭据时不能 bind")
            try require(request.body["jwxtToken"] == (index == 1 ? "old-child" : "new-child"), "子会话没有复用")
            return .json(index == 1 ? #"{"code":2,"data":[],"token":"new-child"}"# : #"{"code":2,"data":[]}"#)
        }
        let store = V3MemoryStore(.init(portalToken: "cached", expireAt: 1, jwxtToken: "old-child"))
        let session = fixture.makeSession(store)
        try require(await fixture.server.count() == 0, "初始化不得登录")
        _ = try await query(session, password: "")
        _ = try await query(session, password: "")
        try require(store.load(username: "test-user")?.jwxtToken == "new-child", "缺失 token 字段不能清空已有子会话")
    }

    func concurrentRenewal() async throws
    {
        let fixture = V3Fixture { request, _ in
            if request.endpoint == "bind"
            {
                try await Task.sleep(nanoseconds: 30_000_000)
                return .json(V3Fixture.portalJSON)
            }
            if request.body["portalToken"] == "expired" { return .json(#"{"code":23,"msg":"expired"}"#) }
            try require(request.body["jwxtToken"] != "stale-child", "续期后仍携带旧子会话")
            return .json(#"{"code":2,"data":[],"token":"fresh-child"}"#)
        }
        let store = V3MemoryStore(.init(portalToken: "expired", jwxtToken: "stale-child"))
        let session = fixture.makeSession(store)
        try await withThrowingTaskGroup(of: Void.self)
        { group in
            for _ in 0 ..< 12 { group.addTask { _ = try await query(session) } }
            try await group.waitForAll()
        }
        try require(await fixture.server.count("bind") == 1, "并发续期必须单飞")
        try require(store.load(username: "test-user")?.jwxtToken == "fresh-child", "等待者不能再次清空子会话")
    }

    func renewalCooldown() async throws
    {
        let fixture = V3Fixture { request, index in
            if request.endpoint == "bind" { return .json(V3Fixture.portalJSON) }
            return .json(index == 1 ? #"{"code":23,"msg":"retry"}"# : #"{"code":2,"data":[]}"#)
        }
        let session = fixture.makeSession(V3MemoryStore())
        try await session.bind(username: "test-user", encryptedPassword: "mock_RSA", mfa: nil)
        _ = try await query(session)
        try require(await fixture.server.count("bind") == 1, "30秒内应复用新门户凭据")
    }

    func stopRetrying() async throws
    {
        let fixture = V3Fixture { request, _ in
            .json(request.endpoint == "bind" ? V3Fixture.portalJSON : #"{"code":23,"msg":"expired again"}"#)
        }
        let store = V3MemoryStore(.init(portalToken: "expired"))
        let session = fixture.makeSession(store)
        try await expectFailure("重新绑定") { _ = try await query(session) }
        try require(await fixture.server.count("bind") == 1, "不能重复续期")
        try require(await fixture.server.count("score") == 2, "不能无限重放")
        try require(store.load(username: "test-user") == nil, "第二次23后必须清空凭据")
        let count = await fixture.server.count()
        try await expectFailure("重新绑定") { _ = try await query(session) }
        try require(await fixture.server.count() == count, "失效后必须等待用户重新绑定")
    }

    func renewalFailure() async throws
    {
        let fixture = V3Fixture { request, _ in
            .json(request.endpoint == "bind" ? #"{"code":5,"msg":"账号或密码错误","data":false}"# : #"{"code":23}"#)
        }
        let store = V3MemoryStore(.init(portalToken: "expired", jwxtToken: "child"))
        try await expectFailure("账号或密码错误") { _ = try await query(fixture.makeSession(store)) }
        try require(store.load(username: "test-user") == nil, "续期失败应清空门户和子会话")
    }

    func bindMFA() async throws
    {
        let fixture = V3Fixture { request, index in
            if request.endpoint == "bind" { return .json(V3Fixture.challengeJSON) }
            try require(request.endpoint == "submitCode", "验证码不应重新 bind")
            return .json(index == 1 ? #"{"code":5,"msg":"验证码错误，剩余4次尝试机会"}"# : V3Fixture.portalJSON)
        }
        let prompts = await V3Prompts(["wrong", "123456"])
        let store = V3MemoryStore()
        try await fixture.makeSession(store).bind(username: "test-user", encryptedPassword: "mock_RSA", mfa: prompts.provider)
        try require(await prompts.messages == [nil, "验证码错误，剩余4次尝试机会"], "错误验证码应允许重新输入并展示服务端说明")
        try require(store.load(username: "test-user")?.portalToken == "portal", "短信成功必须读取门户对象")
        try require(await fixture.server.count("bind") == 1, "输错验证码不能频繁登录")
    }

    func businessMFA() async throws
    {
        let fixture = V3Fixture { request, index in
            if request.endpoint == "bind" { return .json(V3Fixture.portalJSON) }
            if request.endpoint == "submitCode" { return .json(V3Fixture.portalJSON) }
            try require(request.endpoint == "score", "业务22应直接验证，不重复bind")
            return .json(index == 1 ? V3Fixture.challengeJSON : #"{"code":2,"data":[]}"#)
        }
        let prompts = await V3Prompts(["123456"])
        let store = V3MemoryStore()
        let session = fixture.makeSession(store)
        try await session.bind(username: "test-user", encryptedPassword: "mock_RSA", mfa: nil)
        _ = try await query(session, mfa: prompts.provider)
        try require(store.load(username: "test-user")?.portalToken == "portal", "业务验证码成功后应更新门户并重放")
        try require(await fixture.server.count("bind") == 1, "刚登录遇到业务22仍应补短信，而不是反复bind")
    }

    func renewalMFA() async throws
    {
        let fixture = V3Fixture { request, index in
            if request.endpoint == "bind" { return .json(V3Fixture.challengeJSON) }
            if request.endpoint == "submitCode" { return .json(V3Fixture.portalJSON) }
            return .json(index == 1 ? #"{"code":23}"# : #"{"code":2,"data":[]}"#)
        }
        let prompts = await V3Prompts(["123456"])
        _ = try await query(fixture.makeSession(V3MemoryStore(.init(portalToken: "old"))), mfa: prompts.provider)
        try require(await fixture.server.count("bind") == 1, "验证码续期不应重复bind")
        try require(await prompts.messages.count == 1, "静默续期也必须支持短信验证")
    }

    func cancelMFA() async throws
    {
        let fixture = V3Fixture { _, _ in .json(V3Fixture.challengeJSON) }
        let prompts = await V3Prompts([nil])
        let store = V3MemoryStore()
        do
        {
            _ = try await query(fixture.makeSession(store), mfa: prompts.provider)
            throw V3Failure("取消验证码后请求仍成功")
        }
        catch is CancellationError { }
        try require(await fixture.server.count() == 1 && store.load(username: "test-user") == nil, "取消后不应重放业务或保存凭据")
    }

    func smsCooldown() async throws
    {
        let fixture = V3Fixture { _, _ in
            try await Task.sleep(nanoseconds: 20_000_000)
            return .json(#"{"code":2,"data":"已发送"}"#)
        }
        let clock = V3Clock()
        let session = fixture.makeSession(V3MemoryStore(), now: { clock.now })
        try await withThrowingTaskGroup(of: Void.self)
        { group in
            for _ in 0 ..< 8 { group.addTask { try await session.sendCode(sessionId: "sms") } }
            try await group.waitForAll()
        }
        try require(await fixture.server.count() == 1, "并发点击不应重复发短信")
        try await expectFailure("60 秒") { try await session.sendCode(sessionId: "sms") }
        clock.advance(59)
        try require(await session.remainingSMSCooldown(sessionId: "sms") == 1, "冷却时间应跨Sheet保留")
        clock.advance(1)
        try await session.sendCode(sessionId: "sms")
        try require(await fixture.server.count() == 2, "60秒后应允许重新发送")
    }

    func failedSMS() async throws
    {
        let fixture = V3Fixture { _, index in
            .json(index == 1 ? #"{"code":5,"msg":"短信服务忙"}"# : #"{"code":2}"#)
        }
        let session = fixture.makeSession(V3MemoryStore())
        try await expectFailure("短信服务忙") { try await session.sendCode(sessionId: "sms") }
        try require(await session.remainingSMSCooldown(sessionId: "sms") == 0, "发送失败不能启动倒计时")
        try await session.sendCode(sessionId: "sms")
    }

    func logoutRace() async throws
    {
        let gate = V3Gate()
        let fixture = V3Fixture { request, _ in
            if request.endpoint == "score"
            {
                await gate.arriveAndWait()
                return .json(#"{"code":2,"data":[],"token":"late-child"}"#)
            }
            try require(request.body["portalToken"] == "old", "应吊销退出前的门户")
            return .json(#"{"code":2}"#)
        }
        let store = V3MemoryStore(.init(portalToken: "old"))
        let session = fixture.makeSession(store)
        let queryTask = Task { try await query(session) }
        await gate.waitForArrival()
        let revoke = await session.signOut(username: "test-user")
        try require(store.load(username: "test-user") == nil, "本地退出不应等待网络")
        await gate.release()
        do { _ = try await queryTask.value; throw V3Failure("退出后的旧请求没有终止") }
        catch is CancellationError { }
        await revoke?.value
        try require(store.load(username: "test-user") == nil, "退出后旧响应不能复活会话")
        try require(await fixture.server.count("revoke") == 1, "退出时应调用revoke")
    }

    func rebindRace() async throws
    {
        let gate = V3Gate()
        let fixture = V3Fixture { request, _ in
            if request.endpoint == "bind" { return .json(V3Fixture.portalJSON) }
            await gate.arriveAndWait()
            return .json(#"{"code":2,"data":[],"token":"obsolete-child"}"#)
        }
        let store = V3MemoryStore(.init(portalToken: "old"))
        let session = fixture.makeSession(store)
        let task = Task { try await query(session) }
        await gate.waitForArrival()
        try await session.bind(username: "test-user", encryptedPassword: "mock_RSA", mfa: nil)
        await gate.release()
        do { _ = try await task.value; throw V3Failure("重新绑定后旧请求没有终止") }
        catch is CancellationError { }
        try require(store.load(username: "test-user") == .init(portalToken: "portal", expireAt: 1790000000000), "旧响应污染了新门户的子会话")
    }

    func cancelledWaiter() async throws
    {
        let gate = V3Gate()
        let fixture = V3Fixture { request, _ in
            if request.endpoint == "bind" { await gate.arriveAndWait(); return .json(V3Fixture.portalJSON) }
            return .json(request.body["portalToken"] == "old" ? #"{"code":23}"# : #"{"code":2,"data":[]}"#)
        }
        let store = V3MemoryStore(.init(portalToken: "old"))
        let session = fixture.makeSession(store)
        let cancelled = Task { try await query(session) }
        await gate.waitForArrival()
        let other = Task { try await query(session) }
        cancelled.cancel()
        await gate.release()
        do { _ = try await cancelled.value; throw V3Failure("已取消请求不应继续返回结果") }
        catch is CancellationError { }
        _ = try await other.value
        try require(await fixture.server.count("bind") == 1 && store.load(username: "test-user") != nil, "取消一个等待者不能取消其他请求的续期")
    }

    func serverMessages() async throws
    {
        for code in [3, 5]
        {
            let fixture = V3Fixture { _, _ in .json("{\"code\":\(code),\"msg\":\"上游业务说明\",\"data\":42}") }
            try await expectFailure("上游业务说明") { _ = try await query(fixture.makeSession(V3MemoryStore(.init(portalToken: "portal")))) }
        }
        let fixture = V3Fixture { _, _ in V3Reply(status: 503, body: #"{"code":5,"msg":"维护中"}"#) }
        try await expectFailure("维护中") { _ = try await query(fixture.makeSession(V3MemoryStore(.init(portalToken: "portal")))) }
        try require(await fixture.server.count() == 1, "V3 POST 失败不能自动重发")
        let expired = V3Fixture { _, _ in .json(#"{"code":23}"#) }
        try await expectFailure("重新绑定") { _ = try await query(expired.makeSession(V3MemoryStore(.init(portalToken: "portal"))), password: "") }
        try require(await expired.server.count("bind") == 0, "未记住密码时不能伪造续期")
    }

    func otherCourses() throws
    {
        let json = #"{"timetableModels":[{"name":"普通课程","day":1,"start":1,"step":2,"weekList":[4,8,9],"weeks":"4周,8-9周"}],"others":["综合实践○测试教师(共1周)/18周/无","毕业论文◇另一教师（共3周）/2-4周/无"]}"#
        let payload = try JSONDecoder().decode(TimetableData.self, from: Data(json.utf8))
        let courses = try ShishanyouniCurriculumImporter.parseCourses(from: payload, year: "2026", term: "1")
        try require(courses.count == 3 && courses[0].weeks == "4周,8-9周", "V3 weeks 字段或课程数量错误")
        let others = Array(courses.dropFirst())
        try require(others.map(\.name) == ["综合实践", "毕业论文"] && others.map(\.teacher) == ["测试教师", "另一教师"], "其他课程名称、教师解析错误")
        try require(others.map(\.weekList) == [[18], [2, 3, 4]] && others.allSatisfy { $0.courseType == .other && !$0.hasScheduledTime }, "其他课程不能虚构节次")
        let again = try ShishanyouniCurriculumImporter.parseCourses(from: payload, year: "2026", term: "1")
        try require(courses.map(\.id) == again.map(\.id), "课程ID应可稳定保存")
        let invalid = try JSONDecoder().decode(TimetableData.self, from: Data(#"{"others":["损坏课程/未知周次"]}"#.utf8))
        do
        {
            _ = try ShishanyouniCurriculumImporter.parseCourses(from: invalid, year: "2026", term: "1")
            throw V3Failure("损坏的其他课程被静默丢弃")
        }
        catch is CurriculumError { }
        let distinctWeeks = #"{"timetableModels":[{"name":"同名课程","day":1,"start":1,"step":2,"weekList":[1,2,4]},{"name":"同名课程","day":1,"start":1,"step":2,"weekList":[1,3,4]}]}"#
        let distinctPayload = try JSONDecoder().decode(TimetableData.self, from: Data(distinctWeeks.utf8))
        let distinct = try ShishanyouniCurriculumImporter.parseCourses(from: distinctPayload, year: "2026", term: "1")
        try require(distinct.count == 2 && Set(distinct.map(\.id)).count == 2, "首末周和周数相同但实际周次不同的课程不能被去重")
    }

    func mfaSessionLimits() async throws
    {
        for expired in [true, false]
        {
            let message = expired ? "会话不存在或已过期，请重新登录" : "验证码错误，剩余0次尝试机会"
            let fixture = V3Fixture { request, _ in
                .json(request.endpoint == "bind" ? V3Fixture.challengeJSON : "{\"code\":5,\"msg\":\"\(message)\"}")
            }
            let prompts = await V3Prompts(Array(repeating: "wrong", count: 6))
            let store = V3MemoryStore()
            try await expectFailure(message)
            {
                try await fixture.makeSession(store).bind(username: "test-user", encryptedPassword: "mock_RSA", mfa: prompts.provider)
            }
            try require(await fixture.server.count("submitCode") == (expired ? 1 : 5), "过期或错误五次后必须停止提交")
            try require(await fixture.server.count("bind") == 1, "会话失败不能自动循环登录")
            try require(store.load(username: "test-user") == nil, "失败的短信会话不能保存门户")
        }
    }

    func logoutDuringRenewal() async throws
    {
        let gate = V3Gate()
        let fixture = V3Fixture { request, _ in
            if request.endpoint == "bind" { await gate.arriveAndWait(); return .json(V3Fixture.portalJSON) }
            return .json(request.endpoint == "revoke" ? #"{"code":2}"# : #"{"code":23}"#)
        }
        let store = V3MemoryStore(.init(portalToken: "old"))
        let session = fixture.makeSession(store)
        let task = Task { try await query(session) }
        await gate.waitForArrival()
        let revoke = await session.signOut(username: "test-user")
        await gate.release()
        do { _ = try await task.value; throw V3Failure("退出后进行中的续期仍成功") }
        catch where error is CancellationError || (error as NSError).code == NSURLErrorCancelled { }
        await revoke?.value
        try require(store.load(username: "test-user") == nil, "退出后的续期不得写回凭据")
    }

    func storageFailure() async throws
    {
        let fixture = V3Fixture { _, _ in .json(V3Fixture.portalJSON) }
        let store = V3MemoryStore(rejectWrites: true)
        try await expectFailure("无法安全保存")
        {
            try await fixture.makeSession(store).bind(username: "test-user", encryptedPassword: "mock_RSA", mfa: nil)
        }
        try require(store.load(username: "test-user") == nil, "安全存储失败不能标记为已登录")
    }
}

private func query(_ session: ShishanyouniV3Session, password: String = "mock_RSA", mfa: ShishanyouniV3MFAProvider? = nil) async throws -> Data
{
    try await session.request(.score, username: "test-user", encryptedPassword: password, parameters: ["xnm": "2026", "xqm": "1"], mfa: mfa)
}

private struct V3Failure: LocalizedError
{
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

private func require(_ value: Bool, _ message: String) throws
{
    if !value { throw V3Failure(message) }
}

private func expectFailure(_ text: String, operation: () async throws -> Void) async throws
{
    do { try await operation() }
    catch
    {
        try require(error.localizedDescription.contains(text), "未收到预期错误：\(text)，实际：\(error.localizedDescription)")
        return
    }
    throw V3Failure("请求应失败：\(text)")
}

private struct V3Reply: Sendable
{
    let status: Int
    let body: String
    static func json(_ body: String) -> Self { .init(status: 200, body: body) }
}

private struct V3ObservedRequest: Sendable
{
    let endpoint: String
    let method: String?
    let contentType: String?
    let query: String?
    let body: [String: String]
    let numericType: Bool

    init(_ request: URLRequest) throws
    {
        endpoint = request.url?.lastPathComponent ?? ""
        method = request.httpMethod
        contentType = request.value(forHTTPHeaderField: "Content-Type")
        query = request.url?.query
        var data = request.httpBody ?? Data()
        if data.isEmpty, let stream = request.httpBodyStream
        {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable
            {
                let length = stream.read(&buffer, maxLength: buffer.count)
                if length <= 0 { break }
                data.append(buffer, count: length)
            }
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        body = json.mapValues { String(describing: $0) }
        numericType = json["type"] is NSNumber
    }
}

private actor V3MockServer
{
    typealias Handler = @Sendable (V3ObservedRequest, Int) async throws -> V3Reply
    let handler: Handler
    private var requests: [V3ObservedRequest] = []
    init(_ handler: @escaping Handler) { self.handler = handler }
    func respond(_ request: URLRequest) async throws -> V3Reply
    {
        let observed = try V3ObservedRequest(request)
        requests.append(observed)
        return try await handler(observed, count(observed.endpoint))
    }
    func count(_ endpoint: String? = nil) -> Int
    {
        requests.filter { endpoint == nil || $0.endpoint == endpoint }.count
    }
}

private final class V3MockURLProtocol: URLProtocol, @unchecked Sendable
{
    private static let lock = NSLock()
    private static var servers: [String: V3MockServer] = [:]
    private var loadingTask: Task<Void, Never>?
    static func register(_ server: V3MockServer, host: String)
    {
        lock.lock(); defer { lock.unlock() }
        servers[host] = server
    }
    static func unregister(host: String)
    {
        lock.lock(); defer { lock.unlock() }
        servers[host] = nil
    }
    private static func server(for host: String) -> V3MockServer?
    {
        lock.lock(); defer { lock.unlock() }
        return servers[host]
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading()
    {
        loadingTask = Task
        {
            do
            {
                guard let url = request.url, let server = Self.server(for: url.host ?? "") else { throw V3Failure("禁止未注册的真实网络请求") }
                let reply = try await server.respond(request)
                try Task.checkCancellation()
                let response = HTTPURLResponse(url: url, statusCode: reply.status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: Data(reply.body.utf8))
                client?.urlProtocolDidFinishLoading(self)
            }
            catch { client?.urlProtocol(self, didFailWithError: error) }
        }
    }
    override func stopLoading() { loadingTask?.cancel() }
}

private final class V3Fixture: @unchecked Sendable
{
    static let portalJSON = #"{"code":2,"data":{"portalToken":"portal","expireAt":1790000000000}}"#
    static let challengeJSON = #"{"code":22,"msg":"需要短信验证","data":{"sessionId":"sms-session","phone":"133****0000"}}"#
    let server: V3MockServer
    let api: ShishanyouniV3API
    private let urlSession: URLSession
    private let host = "v3-\(UUID().uuidString.lowercased()).invalid"
    init(_ handler: @escaping V3MockServer.Handler)
    {
        server = V3MockServer(handler)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [V3MockURLProtocol.self]
        urlSession = URLSession(configuration: configuration)
        api = .init(session: urlSession, baseURL: URL(string: "https://\(host)/app/ios/v3")!)
        V3MockURLProtocol.register(server, host: host)
    }
    deinit
    {
        urlSession.invalidateAndCancel()
        V3MockURLProtocol.unregister(host: host)
    }
    func makeSession(_ store: V3MemoryStore, now: @escaping @Sendable () -> Date = { Date() }) -> ShishanyouniV3Session
    {
        .init(api: api, storage: store, now: now)
    }
}

private final class V3MemoryStore: ShishanyouniV3CredentialStorage, @unchecked Sendable
{
    private let lock = NSLock()
    private var values: [String: ShishanyouniV3Credentials] = [:]
    private let rejectWrites: Bool
    init(_ credentials: ShishanyouniV3Credentials? = nil, rejectWrites: Bool = false)
    {
        values["test-user"] = credentials
        self.rejectWrites = rejectWrites
    }
    func load(username: String) -> ShishanyouniV3Credentials?
    {
        lock.lock(); defer { lock.unlock() }
        return values[username]
    }
    func save(_ credentials: ShishanyouniV3Credentials, username: String) throws
    {
        if rejectWrites { throw ShishanyouniV3Error.storageUnavailable }
        lock.lock(); defer { lock.unlock() }
        values[username] = credentials
    }
    func remove(username: String)
    {
        lock.lock(); defer { lock.unlock() }
        values[username] = nil
    }
}

private final class V3Clock: @unchecked Sendable
{
    private let lock = NSLock()
    private var value = Date(timeIntervalSince1970: 1_000)
    var now: Date { lock.lock(); defer { lock.unlock() }; return value }
    func advance(_ seconds: TimeInterval) { lock.lock(); defer { lock.unlock() }; value.addTimeInterval(seconds) }
}

@MainActor
private final class V3Prompts
{
    private var codes: [String?]
    private(set) var messages: [String?] = []
    init(_ codes: [String?]) { self.codes = codes }
    var provider: ShishanyouniV3MFAProvider
    {
        { [self] challenge in
            messages.append(challenge.validationMessage)
            return codes.isEmpty ? nil : codes.removeFirst()
        }
    }
}

private actor V3Gate
{
    private var arrived = false
    private var arrival: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?
    func arriveAndWait() async
    {
        arrived = true
        arrival?.resume()
        arrival = nil
        await withCheckedContinuation { releaseContinuation = $0 }
    }
    func waitForArrival() async
    {
        if !arrived { await withCheckedContinuation { arrival = $0 } }
    }
    func release() { releaseContinuation?.resume(); releaseContinuation = nil }
}

#if V3_OFFLINE_TESTS
@main
private struct V3OfflineRunner
{
    static func main() async throws
    {
        for scenario in V3TestScenario.allCases
        {
            try await scenario.run()
            print("PASS \(scenario.rawValue)")
        }
        print("V3 offline tests: \(V3TestScenario.allCases.count) passed")
    }
}
#endif
