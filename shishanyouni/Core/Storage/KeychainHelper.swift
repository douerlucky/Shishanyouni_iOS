//
//  KeychainHelper.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/9.
//

import Foundation
import Security

class KeychainHelper
{
    static let shared = KeychainHelper()

    private init() {}

    // 保存密码到 Keychain
    func save(password: String, for account: String) -> Bool
    {
        guard let data = password.data(using: .utf8) else { return false }

        // 先删除旧的
        delete(for: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: "com.shishanyouni.userPassword",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // 从 Keychain 读取密码
    func get(for account: String) -> String?
    {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: "com.shishanyouni.userPassword",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let password = String(data: data, encoding: .utf8)
        else
        {
            return nil
        }

        return password
    }

    // 删除密码
    func delete(for account: String)
    {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: "com.shishanyouni.userPassword",
        ]
        SecItemDelete(query as CFDictionary)
    }
}
