import Foundation

/// 本机保存“下次不再提醒”的授权记录。
///
/// 记录只在用户明确勾选后写入；未勾选时授权仅对当前页面生命周期有效。
/// key 还包含账号，切换账号不会沿用上一位用户的同意记录。
enum FeatureAuthorizationStore
{
    private static let keyPrefix = "feature_authorization."

    static func isAuthorized(
        _ scope: FeatureAuthorizationScope,
        account: String
    ) -> Bool
    {
        UserDefaults.standard.bool(forKey: key(for: scope, account: account))
    }

    static func rememberAuthorization(
        _ scope: FeatureAuthorizationScope,
        account: String
    )
    {
        UserDefaults.standard.set(true, forKey: key(for: scope, account: account))
    }

    static func revokeAll()
    {
        let defaults = UserDefaults.standard
        defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(keyPrefix) }
            .forEach { defaults.removeObject(forKey: $0) }
    }

    private static func key(
        for scope: FeatureAuthorizationScope,
        account: String
    ) -> String
    {
        let trimmedAccount = account.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAccount = trimmedAccount.isEmpty ? "anonymous" : trimmedAccount
        return "\(keyPrefix)\(scope.rawValue).\(normalizedAccount)"
    }
}
