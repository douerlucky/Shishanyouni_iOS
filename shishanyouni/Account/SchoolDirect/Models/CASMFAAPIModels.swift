import Foundation

// 学校统一身份认证的验证码接口响应。


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
