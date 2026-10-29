import Foundation

/// portalToken 与 jwxtToken 语义不同，不能与旧版 token 混用。
struct ShishanyouniV3Credentials: Codable, Equatable, Sendable
{
    var portalToken: String
    var expireAt: Int64?
    var jwxtToken: String?
}

struct ShishanyouniV3Portal: Decodable, Sendable
{
    let portalToken: String
    let expireAt: Int64?
}

struct ShishanyouniV3Challenge: Decodable, Sendable
{
    let sessionId: String
    let phone: String?
    var validationMessage: String?
}

typealias ShishanyouniV3MFAProvider = @MainActor @Sendable (ShishanyouniV3Challenge) async -> String?

/// 先只解码包装层：失败时 data 可能是验证码对象或攻略 ID，而不是业务模型。
struct ShishanyouniV3Header: Decodable, Sendable
{
    let code: Int
    let msg: String
    let token: String?

    private enum CodingKeys: String, CodingKey { case code, msg, token }

    init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let code = try? container.decode(Int.self, forKey: .code)
        {
            self.code = code
        }
        else
        {
            let value = try container.decode(String.self, forKey: .code)
            guard let code = Int(value) else { throw ShishanyouniV3Error.invalidResponse }
            self.code = code
        }
        msg = try container.decodeIfPresent(String.self, forKey: .msg) ?? "狮山有你请求失败。"
        token = try container.decodeIfPresent(String.self, forKey: .token)
    }
}

struct ShishanyouniV3Data<Value: Decodable>: Decodable
{
    let data: Value
}

struct ShishanyouniV3Response: Sendable
{
    let header: ShishanyouniV3Header
    let rawData: Data

    func payload<Value: Decodable>(_ type: Value.Type) throws -> Value
    {
        try JSONDecoder().decode(ShishanyouniV3Data<Value>.self, from: rawData).data
    }
}

enum ShishanyouniV3Error: LocalizedError, Sendable
{
    case invalidResponse
    case invalidParameters
    case business(String)
    case loginRequired
    case storageUnavailable
    case httpStatus(Int)

    var errorDescription: String?
    {
        switch self
        {
        case .invalidResponse: return "狮山有你服务器返回了无法识别的数据。"
        case .invalidParameters: return "查询参数不符合 V3 接口要求，请更新应用后重试。"
        case let .business(message): return message
        case .loginRequired: return "狮山有你登录状态已失效，请重新绑定账号；已保存的账号密码会保留。"
        case .storageUnavailable: return "无法安全保存登录凭据，请解锁设备后重试。"
        case let .httpStatus(status): return "狮山有你请求失败（HTTP \(status)），请稍后重试。"
        }
    }
}
