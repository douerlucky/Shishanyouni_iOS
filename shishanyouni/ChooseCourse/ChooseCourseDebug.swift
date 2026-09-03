//
//  ChooseCourseDebug.swift
//  shishanyouni
//
//  选课链路的 Debug 诊断日志。仅在 Debug 构建输出，且永远不输出 Cookie、学号、
//  密码或教学班临时 token；这样可以定位卡点，又不会把可用凭据带进控制台记录。
//

import Foundation

enum ChooseCourseDebug
{
    static func info(_ message: @autoclosure () -> String)
    {
        #if DEBUG
        print("ℹ️ [ChooseCourse] \(sanitize(message()))")
        #endif
    }

    static func warning(_ message: @autoclosure () -> String)
    {
        #if DEBUG
        print("⚠️ [ChooseCourse] \(sanitize(message()))")
        #endif
    }

    static func error(_ message: @autoclosure () -> String)
    {
        #if DEBUG
        print("❌ [ChooseCourse] \(sanitize(message()))")
        #endif
    }

    /// 记录请求所处的接口阶段和参数是否齐全；参数值本身一律不回显。
    static func request(
        url: URL,
        method: String,
        parameters: [(String, String)],
        retryCount: Int,
        hasCookie: Bool
    )
    {
        info(
            "HTTP → \(operationName(for: url)) | \(method.uppercased()) | "
                + "Cookie=\(hasCookie ? "有" : "无") | 重试=\(retryCount) | "
                + "参数[\(parameterSummary(parameters))]"
        )
    }

    /// 只输出状态码、长度和 JSON 结构；对安全的顶层标量补充类型和值，
    /// 便于识别 `1\r\n` 这类规则检查响应，同时不输出完整响应正文。
    static func response(url: URL, response: HTTPURLResponse, data: Data)
    {
        let contentType = response.value(forHTTPHeaderField: "Content-Type") ?? "未提供"
        info(
            "HTTP ← \(operationName(for: url)) | 状态=\(response.statusCode) | "
                + "长度=\(data.count)B | 类型=\(contentType) | \(responseShape(data))"
        )
    }

    static func requestFailed(url: URL, error: Error)
    {
        self.error("HTTP × \(operationName(for: url)) | \(error.localizedDescription)")
    }

    /// 页面隐藏字段的诊断只列出“字段名是否存在”，让缺字段问题可见而不泄露字段值。
    static func context(
        _ phase: String,
        values: [String: String],
        requiredFields: [String] = []
    )
    {
        let populated = values
            .filter { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map(\.key)
            .sorted()
        let missing = requiredFields.filter
        {
            values[$0]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
        }
        info(
            "\(phase) 上下文：已取到 \(populated.count) 项"
                + (populated.isEmpty ? "" : " [\(populated.joined(separator: ","))]")
                + (missing.isEmpty ? "" : "；缺少 [\(missing.joined(separator: ","))]")
        )
    }

    private static func operationName(for url: URL) -> String
    {
        let path = url.path
        if path.contains("cxZzxkYzbIndex") { return "选课页入口" }
        if path.contains("cxZzxkYzbDisplay") { return "选课页初始化" }
        if path.contains("cxZzxkYzbPartDisplay") { return "课程目录" }
        if path.contains("cxJxbWithKch") { return "主教学班补全" }
        if path.contains("xkZyZzxkYzbZjxb") { return "子教学班弹窗" }
        if path.contains("xkZyDisplayZzxkYzbZjxb") { return "子教学班列表" }
        if path.contains("xkBcZyZzxkYzb") { return "选课提交" }
        if path.contains("xkJcInXksj") { return "退选规则检查" }
        if path.contains("tuikBc") { return "退选提交" }
        if path.contains("xkBcZypx") { return "志愿顺序同步" }
        if path.contains("cxZkcZzxkYzb") { return "已选实验/子教学班" }
        if path.contains("ChoosedDisplay") { return "已选课程" }
        return url.lastPathComponent
    }

    private static func parameterSummary(_ parameters: [(String, String)]) -> String
    {
        parameters
            .map { name, value in "\(name)=\(value.isEmpty ? "∅" : "✓")" }
            .joined(separator: ",")
    }

    private static func responseShape(_ data: Data) -> String
    {
        guard let payload = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else
        {
            let first = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .first
            return first == "<" ? "HTML" : "非 JSON"
        }

        if let array = payload as? [Any] { return "JSON 数组(\(array.count)项)" }
        if let object = payload as? [String: Any]
        {
            return "JSON 对象(键: \(object.keys.sorted().prefix(8).joined(separator: ",")))"
        }
        if let value = payload as? NSNumber
        {
            return "JSON 标量(数字/布尔)=\(safeScalarDescription(value))"
        }
        if let value = payload as? String
        {
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let safeValues = ["0", "1", "true", "false", "yes", "no", "success", "ok", "fail", "error"]
            return safeValues.contains(normalized) ? "JSON 标量(文本)=\(normalized)" : "JSON 标量(文本)"
        }
        return "JSON 标量"
    }

    private static func safeScalarDescription(_ value: NSNumber) -> String
    {
        let number = value.stringValue.lowercased()
        return ["0", "1", "true", "false"].contains(number) ? number : "<已隐藏>"
    }

    /// 防御性脱敏：即使未来某条错误信息意外携带 URL 或 token，也不会原样打印。
    private static func sanitize(_ text: String) -> String
    {
        var result = text
        let tokenPattern = #"(?i)(?<![0-9a-f])[0-9a-f]{24,}(?![0-9a-f])"#
        result = result.replacingOccurrences(of: tokenPattern, with: "<已隐藏>", options: .regularExpression)
        let queryPattern = #"(?i)(JSESSIONID|SESSION|TGC|ticket|password|cookie|do_jxb_id|jxb_ids|xh_id)=([^&\s]+)"#
        return result.replacingOccurrences(of: queryPattern, with: "$1=<已隐藏>", options: .regularExpression)
    }
}
