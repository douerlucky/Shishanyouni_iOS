import Foundation

/// V3 传输层不自动重发 POST，尤其不能在超时后再次 bind 或发送短信。
struct ShishanyouniV3API: Sendable
{
    enum Endpoint: String, Sendable
    {
        case bind, sendCode, submitCode, revoke, score, exam, timetable, southlake

        var queryFields: Set<String>
        {
            switch self
            {
            case .score, .exam: return ["xnm", "xqm"]
            case .timetable: return ["year", "term"]
            case .southlake: return []
            default: return []
            }
        }

        var isBusiness: Bool { [.score, .exam, .timetable, .southlake].contains(self) }
        var usesAcademicSession: Bool { [.score, .exam, .timetable].contains(self) }
        var usernameField: String { self == .score || self == .exam ? "yhm" : "username" }
    }

    let session: URLSession
    let baseURL: URL

    init(session: URLSession = .shared, baseURL: URL = URL(string: ShishanyouniAPI.v3BaseURL)!)
    {
        self.session = session
        self.baseURL = baseURL
    }

    func bind(username: String, encryptedPassword: String) async throws -> ShishanyouniV3Response
    {
        guard encryptedPassword.hasSuffix("_RSA") else { throw ShishanyouniV3Error.loginRequired }
        struct Body: Encodable { let username: String; let password: String; let type = 1 }
        return try await post(.bind, body: Body(username: username, password: encryptedPassword))
    }

    func sendCode(sessionId: String) async throws -> ShishanyouniV3Response
    {
        try await post(.sendCode, body: ["sessionId": sessionId])
    }

    func submitCode(sessionId: String, code: String) async throws -> ShishanyouniV3Response
    {
        try await post(.submitCode, body: ["sessionId": sessionId, "smsCode": code])
    }

    func revoke(username: String, portalToken: String) async throws
    {
        let response = try await post(.revoke, body: ["username": username, "portalToken": portalToken], timeout: 10)
        guard response.header.code == 2 else { throw ShishanyouniV3Error.business(response.header.msg) }
    }

    func business(
        _ endpoint: Endpoint,
        username: String,
        credentials: ShishanyouniV3Credentials,
        parameters: [String: String]
    ) async throws -> ShishanyouniV3Response
    {
        guard endpoint.isBusiness, Set(parameters.keys).isSubset(of: endpoint.queryFields) else
        {
            throw ShishanyouniV3Error.invalidParameters
        }
        var body = parameters
        body[endpoint.usernameField] = username
        body["portalToken"] = credentials.portalToken
        if endpoint.usesAcademicSession { body["jwxtToken"] = credentials.jwxtToken ?? "" }
        return try await post(endpoint, body: body)
    }

    private func post<Body: Encodable>(
        _ endpoint: Endpoint, body: Body, timeout: TimeInterval = 120
    ) async throws -> ShishanyouniV3Response
    {
        var request = URLRequest(url: baseURL.appendingPathComponent(endpoint.rawValue))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await NetworkService.perform(
            with: session, request: request, retries: 0, timeout: timeout
        )
        guard let http = response as? HTTPURLResponse else { throw ShishanyouniV3Error.invalidResponse }
        guard (200 ..< 300).contains(http.statusCode) else
        {
            if let header = try? JSONDecoder().decode(ShishanyouniV3Header.self, from: data)
            {
                throw ShishanyouniV3Error.business(header.msg)
            }
            throw ShishanyouniV3Error.httpStatus(http.statusCode)
        }
        return ShishanyouniV3Response(
            header: try JSONDecoder().decode(ShishanyouniV3Header.self, from: data), rawData: data
        )
    }
}
