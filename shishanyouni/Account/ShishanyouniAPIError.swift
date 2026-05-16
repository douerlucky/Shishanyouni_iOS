//
//  ShishanyouniAPIError.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/5/16.
//

import Foundation

enum ShishanyouniAPIError: LocalizedError
{
    case needMFA(phone: String, sessionId: String, message: String)
    case apiError(code: Int?, message: String)
    case invalidResponse

    var errorDescription: String?
    {
        switch self
        {
        case let .needMFA(_, _, message):
            return message
        case let .apiError(code, message):
            if let code
            {
                return "code \(code)：\(message)"
            }
            return message
        case .invalidResponse:
            return "狮山有你服务器返回了无法识别的响应。"
        }
    }

    var mfaSessionId: String?
    {
        if case let .needMFA(_, sessionId, _) = self
        {
            return sessionId
        }
        return nil
    }

    var mfaPhone: String?
    {
        if case let .needMFA(phone, _, _) = self
        {
            return phone
        }
        return nil
    }

    static func throwIfMFAResponse(_ data: Data) throws
    {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              intValue(from: json["code"]) == 22
        else
        {
            return
        }

        guard let dataJSON = json["data"] as? [String: Any],
              let phone = dataJSON["phone"] as? String,
              let sessionId = dataJSON["sessionId"] as? String,
              !sessionId.isEmpty
        else
        {
            throw ShishanyouniAPIError.invalidResponse
        }

        throw ShishanyouniAPIError.needMFA(
            phone: phone,
            sessionId: sessionId,
            message: json["msg"] as? String ?? "需要短信验证码登录"
        )
    }

    private static func intValue(from value: Any?) -> Int?
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
