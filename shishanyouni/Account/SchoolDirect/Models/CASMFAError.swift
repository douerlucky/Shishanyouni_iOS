import Foundation

// 学校安全手机验证的错误。


// CAS 安全验证接口模型位于 Account/SchoolDirect/Models/CASMFAAPIModels.swift。

enum CASMFAError: LocalizedError {
    case needCodeInput
    case cancelled
    case initFailed
    case sendFailed
    case verifyFailed
    case unsupportedType

    var errorDescription: String? {
        switch self {
        case .needCodeInput:
            return "当前登录环境需要安全手机验证码，请输入后重试。"
        case .cancelled:
            return "已取消安全验证。"
        case .initFailed:
            return "初始化安全验证失败。"
        case .sendFailed:
            return "验证码发送失败，请稍后重试。"
        case .verifyFailed:
            return "验证码校验失败，请确认后重试。"
        case .unsupportedType:
            return "当前账号触发了暂不支持的验证方式，请先在网页端登录一次。"
        }
    }
}
