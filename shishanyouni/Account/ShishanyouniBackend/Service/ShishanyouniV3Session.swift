import Foundation

/// 每个账号只有一项续期任务，验证码也在这项任务内完成；所有等待者共用结果。
actor ShishanyouniV3Session
{
    static let shared = ShishanyouniV3Session()

    private final class AccountState
    {
        var credentials: ShishanyouniV3Credentials?
        var encryptedPassword = ""
        var loginTask: Task<ShishanyouniV3Credentials, Error>?
        var lastLoginAt: Date?
        var requiresLogin = false
        var invalidated = false

        init(credentials: ShishanyouniV3Credentials?) { self.credentials = credentials }
    }

    private let api: ShishanyouniV3API
    private let storage: any ShishanyouniV3CredentialStorage
    private let now: @Sendable () -> Date
    private var accounts: [String: AccountState] = [:]
    private var smsTasks: [String: Task<Void, Error>] = [:]
    private var lastSMSSentAt: [String: Date] = [:]

    init(
        api: ShishanyouniV3API = ShishanyouniV3API(),
        storage: any ShishanyouniV3CredentialStorage = ShishanyouniV3CredentialStore(),
        now: @escaping @Sendable () -> Date = { Date() }
    )
    {
        self.api = api
        self.storage = storage
        self.now = now
    }

    /// 只由用户主动绑定调用；绝不在 init、冷启动或读取账号时触发。
    func bind(
        username: String, encryptedPassword: String, mfa: ShishanyouniV3MFAProvider?
    ) async throws
    {
        guard !username.isEmpty else { throw ShishanyouniV3Error.loginRequired }
        if let previous = accounts[username]
        {
            previous.invalidated = true
            previous.loginTask?.cancel()
        }
        let state = AccountState(credentials: nil)
        state.encryptedPassword = encryptedPassword
        accounts[username] = state
        _ = try await renew(username: username, state: state, failedPortal: nil, challenge: nil, mfa: mfa)
    }

    /// encryptedPassword 仅在必要的 bind 中使用，业务 HTTP body 永远不包含密码。
    func request(
        _ endpoint: ShishanyouniV3API.Endpoint,
        username: String,
        encryptedPassword: String,
        parameters: [String: String],
        mfa: ShishanyouniV3MFAProvider?
    ) async throws -> Data
    {
        guard !username.isEmpty, endpoint.isBusiness,
              Set(parameters.keys).isSubset(of: endpoint.queryFields) else
        {
            throw ShishanyouniV3Error.invalidParameters
        }
        let state = account(username)
        guard !state.invalidated, !state.requiresLogin else { throw ShishanyouniV3Error.loginRequired }
        if !encryptedPassword.isEmpty { state.encryptedPassword = encryptedPassword }

        var authenticated = false
        var credentials: ShishanyouniV3Credentials
        if let saved = state.credentials
        {
            credentials = saved
        }
        else
        {
            // 旧版升级或本地凭据缺失：仅在用户实际查询时按需登录，不在启动时登录。
            credentials = try await renew(username: username, state: state, failedPortal: nil, challenge: nil, mfa: mfa)
            authenticated = true
        }

        for _ in 0 ... 1
        {
            try Task.checkCancellation()
            try validate(state, username: username)
            // 其它请求可能已更新子会话，发送前再读取一次；不能用续期任务的旧快照覆盖它。
            if let current = state.credentials { credentials = current }
            let response = try await api.business(endpoint, username: username, credentials: credentials, parameters: parameters)
            try validate(state, username: username)
            try persistChildToken(response.header.token, for: credentials.portalToken, state: state, username: username)

            switch response.header.code
            {
            case 2:
                return response.rawData
            case 22, 23:
                guard !authenticated else
                {
                    clearCredentials(state, username: username)
                    throw ShishanyouniV3Error.loginRequired
                }
                authenticated = true
                credentials = try await renew(
                    username: username, state: state, failedPortal: credentials.portalToken,
                    challenge: response.header.code == 22 ? response : nil, mfa: mfa
                )
            default:
                // code=5 / code=3 的服务器说明必须直接展示，不改成笼统的 LoginFailed。
                throw ShishanyouniV3Error.business(response.header.msg)
            }
        }
        throw ShishanyouniV3Error.loginRequired
    }

    func remainingSMSCooldown(sessionId: String) -> Int
    {
        guard let last = lastSMSSentAt[sessionId] else { return 0 }
        return max(0, Int(ceil(60 - now().timeIntervalSince(last))))
    }

    func sendCode(sessionId: String) async throws
    {
        if let task = smsTasks[sessionId] { return try await task.value }
        let remaining = remainingSMSCooldown(sessionId: sessionId)
        guard remaining == 0 else
        {
            throw ShishanyouniV3Error.business("请在 \(remaining) 秒后重新获取验证码。")
        }
        let task = Task { try await self.performSendCode(sessionId: sessionId) }
        smsTasks[sessionId] = task
        defer { smsTasks[sessionId] = nil }
        try await task.value
    }

    /// 先立即废弃本地会话，再尽力吊销服务器凭据；网络失败不阻塞本地退出。
    @discardableResult
    func signOut(username: String) -> Task<Void, Never>?
    {
        guard !username.isEmpty else { return nil }
        let state = account(username)
        let portalToken = state.credentials?.portalToken
        state.invalidated = true
        state.loginTask?.cancel()
        state.encryptedPassword = ""
        clearCredentials(state, username: username)
        guard let portalToken, !portalToken.isEmpty else { return nil }
        let api = self.api
        return Task { try? await api.revoke(username: username, portalToken: portalToken) }
    }

    private func account(_ username: String) -> AccountState
    {
        if let state = accounts[username] { return state }
        let state = AccountState(credentials: storage.load(username: username))
        accounts[username] = state
        return state
    }

    private func validate(_ state: AccountState, username: String) throws
    {
        guard accounts[username] === state, !state.invalidated else { throw CancellationError() }
        try Task.checkCancellation()
    }

    private func renew(
        username: String,
        state: AccountState,
        failedPortal: String?,
        challenge: ShishanyouniV3Response?,
        mfa: ShishanyouniV3MFAProvider?
    ) async throws -> ShishanyouniV3Credentials
    {
        try validate(state, username: username)
        if let task = state.loginTask { return try await task.value }
        if let current = state.credentials,
           current.portalToken != failedPortal || (challenge == nil && state.lastLoginAt.map({ now().timeIntervalSince($0) < 30 }) == true)
        {
            return current
        }
        guard challenge != nil || state.encryptedPassword.hasSuffix("_RSA") else
        {
            clearCredentials(state, username: username)
            throw ShishanyouniV3Error.loginRequired
        }
        let task = Task
        {
            try await self.authenticate(username: username, state: state, challenge: challenge, mfa: mfa)
        }
        state.loginTask = task
        defer { state.loginTask = nil }
        do { return try await task.value }
        catch
        {
            if accounts[username] === state, !state.invalidated { clearCredentials(state, username: username) }
            throw error
        }
    }

    private func authenticate(
        username: String, state: AccountState, challenge: ShishanyouniV3Response?, mfa: ShishanyouniV3MFAProvider?
    ) async throws -> ShishanyouniV3Credentials
    {
        let response: ShishanyouniV3Response
        if let challenge { response = challenge }
        else { response = try await api.bind(username: username, encryptedPassword: state.encryptedPassword) }
        try validate(state, username: username)
        let portal: ShishanyouniV3Portal
        switch response.header.code
        {
        case 2: portal = try response.payload(ShishanyouniV3Portal.self)
        case 22: portal = try await completeMFA(response, username: username, state: state, provider: mfa)
        default: throw ShishanyouniV3Error.business(response.header.msg)
        }
        guard !portal.portalToken.isEmpty else { throw ShishanyouniV3Error.invalidResponse }
        try validate(state, username: username)
        // 新 TGC 只在这里清一次子会话；并发等待者不能再次清掉刚收到的 jwxtToken。
        let credentials = ShishanyouniV3Credentials(portalToken: portal.portalToken, expireAt: portal.expireAt, jwxtToken: nil)
        try storage.save(credentials, username: username)
        state.credentials = credentials
        state.lastLoginAt = now()
        state.requiresLogin = false
        notify(username)
        return credentials
    }

    private func completeMFA(
        _ response: ShishanyouniV3Response,
        username: String,
        state: AccountState,
        provider: ShishanyouniV3MFAProvider?
    ) async throws -> ShishanyouniV3Portal
    {
        guard let provider else { throw ShishanyouniV3Error.business(response.header.msg) }
        var challenge = try response.payload(ShishanyouniV3Challenge.self)
        guard !challenge.sessionId.isEmpty else { throw ShishanyouniV3Error.invalidResponse }
        for attempt in 0 ..< 5
        {
            try validate(state, username: username)
            guard let code = await provider(challenge), !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else
            {
                throw CancellationError()
            }
            try validate(state, username: username)
            let result = try await api.submitCode(sessionId: challenge.sessionId, code: code.trimmingCharacters(in: .whitespacesAndNewlines))
            try validate(state, username: username)
            if result.header.code == 2 { return try result.payload(ShishanyouniV3Portal.self) }
            let message = result.header.msg
            let sessionEnded = ["过期", "作废", "重新登录", "不存在"].contains { message.contains($0) }
            guard result.header.code == 5, message.contains("验证码"), !sessionEnded, attempt < 4 else
            {
                throw ShishanyouniV3Error.business(message)
            }
            challenge.validationMessage = message
        }
        throw ShishanyouniV3Error.loginRequired
    }

    private func performSendCode(sessionId: String) async throws
    {
        let response = try await api.sendCode(sessionId: sessionId)
        guard response.header.code == 2 else { throw ShishanyouniV3Error.business(response.header.msg) }
        lastSMSSentAt[sessionId] = now()
    }

    private func persistChildToken(_ token: String?, for portal: String, state: AccountState, username: String) throws
    {
        guard let token, var current = state.credentials, current.portalToken == portal else { return }
        current.jwxtToken = token
        try storage.save(current, username: username)
        state.credentials = current
    }

    private func clearCredentials(_ state: AccountState, username: String)
    {
        state.credentials = nil
        state.requiresLogin = true
        storage.remove(username: username)
        notify(username)
    }

    private func notify(_ username: String)
    {
        NotificationCenter.default.post(name: .shishanyouniV3CredentialsChanged, object: username)
    }
}
