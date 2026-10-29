import Foundation

/// 只读取 CAS 明确标记的登录错误，避免把页面里的静态验证说明误判为失败原因。
enum CASLoginFailure
{
    private static let fallback = "\(SchoolServiceName.unifiedIdentity)登录未完成，请重试；若仍失败，请在学校登录页确认验证要求。"

    static func message(from data: Data) -> String
    {
        guard let html = String(data: data, encoding: .utf8) else { return fallback }

        // 学校登录页由 Thymeleaf 输出 hasErrors 和 JSON 字符串数组 errors。
        let scriptPattern = #"(?s)\b(?:var|let|const)\s+hasErrors\s*=\s*true\s*;\s*(?:var|let|const)\s+errors\s*=\s*\[\s*(\"(?:\\.|[^\"\\])*\")"#
        if let encodedMessage = firstCapture(scriptPattern, in: html),
           let decodedMessage = try? JSONDecoder().decode(String.self, from: Data(encodedMessage.utf8)),
           let message = cleanMessage(decodedMessage)
        {
            return message
        }

        let blockPattern = #"(?is)<div\b[^>]*\bid\s*=\s*[\"']loginError1[\"'][^>]*>(.*?)</div\s*>"#
        if let errorBlock = firstCapture(blockPattern, in: html),
           let message = cleanMessage(
               firstCapture(#"(?is)<el-alert\b[^>]*\btitle\s*=\s*[\"']([^\"']+)[\"']"#, in: errorBlock) ?? errorBlock
           )
        {
            return message
        }

        return fallback
    }

    static func error(from data: Data) -> NSError
    {
        NSError(domain: "LoginFailed", code: 401, userInfo: [NSLocalizedDescriptionKey: message(from: data)])
    }

    private static func cleanMessage(_ value: String) -> String?
    {
        let withoutScripts = value.replacingOccurrences(
            of: #"(?is)<(script|style)\b[^>]*>.*?</\1\s*>"#,
            with: " ",
            options: .regularExpression
        )
        var text = withoutScripts.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        for (entity, replacement) in [("&nbsp;", " "), ("&quot;", "\""), ("&#39;", "'"), ("&lt;", "<"), ("&gt;", ">"), ("&amp;", "&")]
        {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // 错误区也不应包含会话字段或不透明长令牌；此时用通用提示，不展示响应片段。
        let sensitivePattern = #"(?i)\b(?:execution|password|passwd|username|token|cookie|ticket)\s*[:=]|__RSA__|[A-Za-z0-9_+/=-]{64,}"#
        guard !text.isEmpty, text.count <= 200,
              text.range(of: sensitivePattern, options: .regularExpression) == nil
        else { return nil }
        return text
    }

    private static func firstCapture(_ pattern: String, in text: String) -> String?
    {
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range])
    }
}
