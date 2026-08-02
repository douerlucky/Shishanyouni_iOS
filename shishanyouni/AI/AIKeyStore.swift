//
//  AIKeyStore.swift
//  shishanyouni
//
//  AI 智学助手（beta）配置存储：API Key 存 Keychain，模型选择存 UserDefaults。
//

import Foundation
import Security

enum AIKeyStore
{
    private static let keychainService = "com.shishanyouni.aiApiKey"
    private static let keychainAccount = "ai_api_key"
    private static let modelKey = "ai_selected_model_id"

    static var apiKey: String
    {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrService as String: keychainService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty
        else
        {
            return ""
        }
        return key
    }

    static var hasAPIKey: Bool
    {
        !apiKey.isEmpty
    }

    static func saveAPIKey(_ key: String)
    {
        deleteAPIKey()
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrService as String: keychainService,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func deleteAPIKey()
    {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrService as String: keychainService,
        ]
        SecItemDelete(query as CFDictionary)
    }

    static var selectedModelID: String
    {
        get
        {
            let saved = UserDefaults.standard.string(forKey: modelKey)
            if let saved, AIService.modelConfig(for: saved) != nil
            {
                return saved
            }
            return AIService.availableModels.first?.id ?? ""
        }
        set
        {
            UserDefaults.standard.set(newValue, forKey: modelKey)
        }
    }

    static var selectedModel: AIModelConfig?
    {
        AIService.modelConfig(for: selectedModelID) ?? AIService.availableModels.first
    }

    static func testConnection() async -> String?
    {
        let key = apiKey
        let model = selectedModel
        guard !key.isEmpty, let model else
        {
            return "请先填写 API Key"
        }

        do
        {
            let reply = try await AIService.sendMessageSync(
                modelId: model.id,
                apiKey: key,
                messages: [ChatAPIMessage(role: "user", content: "回复 ok 即可")],
                systemPrompt: "只回复 ok"
            )
            return reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "连接成功" : "连接成功：\(reply)"
        }
        catch
        {
            return "连接失败：\(error.localizedDescription)"
        }
    }
}
