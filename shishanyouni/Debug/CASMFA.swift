//
//  CASMFA.swift
//  shishanyouni
//
//  Created by Codex on 2026/4/23.
//

import Foundation

typealias MFACodeProvider = @MainActor (_ maskedPhone: String?) async -> String?

enum CASMFADebug {
    private static let randomFPKey = "DebugRandomFPVisitorId"
    private static let fpSessionKey = "DebugMFASessionFPVisitorId"
    private static let defaultFPVisitorId = "cf1df3e32fe5f29e9c91952fed0edc7e"

    static var forcePromptEnabled: Bool {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-DebugForceMFA") {
            return true
        }
        if UserDefaults.standard.bool(forKey: "DebugForceMFA") {
            return true
        }
        return false
        #else
        return false
        #endif
    }

    static var maskedPhone: String {
        #if DEBUG
        if let value = UserDefaults.standard.string(forKey: "DebugMFAPhoneMask"), !value.isEmpty {
            return value
        }
        #endif
        return "133****0922"
    }

    static var randomFPVisitorEnabled: Bool {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-DebugRandomFPVisitorId") {
            return true
        }
        return UserDefaults.standard.bool(forKey: randomFPKey)
        #else
        return false
        #endif
    }

    static var fpVisitorId: String {
        #if DEBUG
        if randomFPVisitorEnabled {
            if let current = UserDefaults.standard.string(forKey: fpSessionKey), !current.isEmpty {
                return current
            }
            let generated = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
            UserDefaults.standard.set(generated, forKey: fpSessionKey)
            return generated
        }
        #endif
        return defaultFPVisitorId
    }

    static func setRandomFPVisitorEnabled(_ enabled: Bool) {
        #if DEBUG
        UserDefaults.standard.set(enabled, forKey: randomFPKey)
        if !enabled {
            UserDefaults.standard.removeObject(forKey: fpSessionKey)
        }
        #endif
    }

    static func regenerateFPVisitorId() {
        #if DEBUG
        let generated = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        UserDefaults.standard.set(generated, forKey: fpSessionKey)
        #endif
    }
}

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
