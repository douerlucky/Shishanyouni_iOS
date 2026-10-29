import Foundation

protocol ShishanyouniV3CredentialStorage: Sendable
{
    func load(username: String) -> ShishanyouniV3Credentials?
    func save(_ credentials: ShishanyouniV3Credentials, username: String) throws
    func remove(username: String)
}

/// 独立的 V3 Keychain 记录；绝不把旧版 token 当作 portalToken 迁移。
struct ShishanyouniV3CredentialStore: ShishanyouniV3CredentialStorage
{
    private func key(_ username: String) -> String { "shishanyouni-v3-credentials-\(username)" }

    func load(username: String) -> ShishanyouniV3Credentials?
    {
        guard let text = KeychainHelper.shared.get(for: key(username)),
              let data = text.data(using: .utf8),
              let credentials = try? JSONDecoder().decode(ShishanyouniV3Credentials.self, from: data),
              !credentials.portalToken.isEmpty else { return nil }
        return credentials
    }

    func save(_ credentials: ShishanyouniV3Credentials, username: String) throws
    {
        let data = try JSONEncoder().encode(credentials)
        guard let text = String(data: data, encoding: .utf8),
              KeychainHelper.shared.save(password: text, for: key(username)) else
        {
            throw ShishanyouniV3Error.storageUnavailable
        }
        KeychainHelper.shared.delete(for: "shishanyouni-token-\(username)")
        UserDefaults.standard.removeObject(forKey: "saved_shishanyouni_token")
    }

    func remove(username: String)
    {
        KeychainHelper.shared.delete(for: key(username))
        KeychainHelper.shared.delete(for: "shishanyouni-token-\(username)")
    }
}

extension Notification.Name
{
    static let shishanyouniV3CredentialsChanged = Notification.Name("shishanyouniV3CredentialsChanged")
}
