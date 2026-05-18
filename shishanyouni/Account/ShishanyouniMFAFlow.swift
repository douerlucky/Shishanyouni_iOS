//
//  ShishanyouniMFAFlow.swift
//  shishanyouni
//
//  Created by Codex on 2026/5/18.
//

import Foundation

enum ShishanyouniMFAFlow
{
    static func sendCodeMessage(sessionId: String) async -> String?
    {
        do
        {
            try await ShishanyouniBinder().sendCode(sessionId: sessionId)
            return nil
        }
        catch
        {
            return error.localizedDescription
        }
    }

    static func submitCode(sessionId: String, smsCode: String) async throws -> String
    {
        try await ShishanyouniBinder().submitCode(sessionId: sessionId, smsCode: smsCode)
    }
}
