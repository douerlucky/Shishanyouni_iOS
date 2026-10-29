// 学校认证的客户端环境；调试覆盖仅在 DEBUG 中启用。

import Foundation

enum CASClientEnvironment {
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
