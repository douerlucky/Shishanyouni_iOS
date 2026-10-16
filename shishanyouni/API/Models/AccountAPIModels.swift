//
//  AccountAPIModels.swift
//  shishanyouni
//
//  账号绑定、短信验证码与 CAS 安全验证接口的响应。
//  这里只定义接口的数据格式；请求执行、错误处理和界面状态留在业务模块。
//

import Foundation

// MARK: - 狮山有你账号绑定

// 保留现有 JSON 字典解析，兼容 code 同时可能为数字或字符串的服务端响应。
/// 狮山有你后端绑定接口返回结构。
struct ShishanyouniBindResponse {
    let msg: String? //返回处理消息(失败时返回对应错误信息)
    let code: Int? //响应编码(200是成功，其它都是失败)
    let data: ShishanyouniBindData? //需要短信验证码时包含手机号和 sessionId
    let success: Bool? // v1 绑定的成功标志

    init(json: [String: Any])
    {
        msg = json["msg"] as? String
        code = Self.intValue(from: json["code"])
        success = json["success"] as? Bool

        if let dataJSON = json["data"] as? [String: Any]
        {
            data = ShishanyouniBindData(json: dataJSON)
        }
        else
        {
            data = nil
        }
    }

    static func intValue(from value: Any?) -> Int?
    {
        if let intValue = value as? Int
        {
            return intValue
        }
        if let stringValue = value as? String
        {
            return Int(stringValue)
        }
        if let numberValue = value as? NSNumber
        {
            return numberValue.intValue
        }
        return nil
    }
}

/// 狮山有你绑定需要短信验证码时返回的 data。
struct ShishanyouniBindData {
    let phone: String?
    let sessionId: String?

    init(json: [String: Any])
    {
        phone = json["phone"] as? String
        sessionId = json["sessionId"] as? String
    }
}

struct ShishanyouniCodeResponse {
    let msg: String?
    let code: Int?
    let data: String?

    init(json: [String: Any])
    {
        msg = json["msg"] as? String
        code = ShishanyouniBindResponse.intValue(from: json["code"])
        data = json["data"] as? String
    }
}

// MARK: - CAS 多因素安全验证

// attestServerUrl 由服务端动态返回，不属于固定 API URL。
struct CASMFADetectResponse: Decodable {
    let code: Int
    let data: CASMFADetectData?
}

struct CASMFADetectData: Decodable {
    let need: Bool
    let state: String?
    let mfaTypeSecurePhone: Bool?
}

struct CASMFAInitResponse: Decodable {
    let code: Int
    let data: CASMFAInitData?
}

struct CASMFAInitData: Decodable {
    let gid: String
    let securePhone: String?
    let attestServerUrl: String
}

struct CASMFACommonResponse: Decodable {
    let code: Int
    let data: CASMFACommonData?
    let message: String?
}

struct CASMFACommonData: Decodable {
    let result: String?
    let status: Int?
}
