import Foundation
import SwiftUI

enum CourseSelectionHTML
{
    static func context(from html: String) -> CourseSelectionContext
    {
        var values: [String: String] = [:]
        let inputPattern = #"(?is)<(?:input|select|textarea)\b[^>]*>"#
        for tag in matches(for: inputPattern, in: html)
        {
            let names = [attribute("name", in: tag), attribute("id", in: tag)].compactMap { $0 }.filter { !$0.isEmpty }
            let value = attribute("value", in: tag) ?? ""
            for rawName in names
            {
                let name = rawName == "jg_id_1" ? "jg_id" : rawName
                guard CourseSelectionContext.responseFields.contains(rawName) || CourseSelectionContext.responseFields.contains(name) else { continue }
                if values[name] == nil || !value.isEmpty
                {
                    values[name] = value
                }
            }
        }

        // 部分页面只通过 JavaScript 给隐藏字段赋值；这里只读取页面明确写出的字面量。
        for rawName in CourseSelectionContext.responseFields
        {
            let name = rawName == "jg_id_1" ? "jg_id" : rawName
            guard values[name].isEmptyOrNil else { continue }
            let escapedName = NSRegularExpression.escapedPattern(for: rawName)
            let literal = #"(?:['\"]([^'\"]*)['\"]|(-?\d+(?:\.\d+)?|true|false))"#
            let patterns = [
                "(?is)(?:var|let|const)?\\s*\(escapedName)\\s*[:=]\\s*\(literal)",
                "(?is)\\$\\(\\s*['\"]#\(escapedName)['\"]\\s*\\)\\s*\\.val\\(\\s*\(literal)\\s*\\)"
            ]
            for pattern in patterns
            {
                if let match = firstCaptures(for: pattern, in: html)
                {
                    values[name] = match.first(where: { !$0.isEmpty }) ?? ""
                    break
                }
            }
        }

        // 选课规则的学分区间在部分模板中不是 input，而是正文里的 font 标签；
        // 截止时间则可能由内联脚本赋给 `sysj`。把它们收集成展示元数据，绝不混入
        // 最终选课 POST 所需的协议字段。
        for (key, value) in presentationMetadata(from: html)
        {
            if values[key].isEmptyOrNil || !value.isEmpty
            {
                values[key] = value
            }
        }
        return CourseSelectionContext(values: values).merged(with: CourseSelectionContext())
    }

    /// Index 页面的五个页签会渲染成 `queryCourse(this, kklxdm, xkkz_id)`。
    /// 这里仅解析网页已经给出的字面量，绝不由学号、专业或历史抓包推导规则 ID。
    static func catalogRules(from html: String) -> [CourseCatalogRule]
    {
        var rules: [CourseCatalogRule] = []
        var seen = Set<String>()
        let anchorPattern = #"(?is)<a\b[^>]*>.*?</a>"#

        for anchor in matches(for: anchorPattern, in: html)
        {
            let handlers = [attribute("onclick", in: anchor), attribute("href", in: anchor)]
                .compactMap { $0 }
            guard let arguments = handlers.lazy.compactMap(queryCourseArguments).first else { continue }

            let visibleTitle: String
            if let openingEnd = anchor.firstIndex(of: ">"),
               let closingStart = anchor.range(of: "</a", options: .caseInsensitive)?.lowerBound
            {
                visibleTitle = visibleText(from: String(anchor[anchor.index(after: openingEnd) ..< closingStart]))
            }
            else
            {
                visibleTitle = ""
            }
            let titles = [visibleTitle, attribute("title", in: anchor), attribute("data-original-title", in: anchor)]
                .compactMap { $0 }
            guard let category = CourseCatalogCategory.allCases.first(where: { candidate in
                titles.contains(where: candidate.matchesServerTitle)
            }) else { continue }

            let courseTypeCode = arguments.0.trimmingCharacters(in: .whitespacesAndNewlines)
            let controlID = arguments.1.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !courseTypeCode.isEmpty, !controlID.isEmpty else { continue }
            let identity = "\(category.rawValue)|\(courseTypeCode)|\(controlID)"
            guard seen.insert(identity).inserted else { continue }
            rules.append(
                CourseCatalogRule(
                    category: category,
                    courseTypeCode: courseTypeCode,
                    controlID: controlID
                )
            )
        }
        return rules
    }

    private static func queryCourseArguments(in handler: String) -> (String, String)?
    {
        // 兼容单双引号以及少数模板里未加引号的数值型开课类型。
        let pattern = #"(?is)\bqueryCourse\s*\(\s*[^,]+,\s*(?:['\"]([^'\"]+)['\"]|([^,\s)]+))\s*,\s*(?:['\"]([^'\"]+)['\"]|([^,\s)]+))\s*\)"#
        guard let captures = firstCaptures(for: pattern, in: handler) else { return nil }
        let values = captures.filter { !$0.isEmpty }
        guard values.count >= 2 else { return nil }
        return (values[0], values[1])
    }

    private static func presentationMetadata(from html: String) -> [String: String]
    {
        var values: [String: String] = [:]
        let text = visibleText(from: html)
        let creditPatterns: [(String, String)] = [
            ("selectionMinimumCredit", #"总学分最低\s*([0-9]+(?:\.[0-9]+)?)"#),
            ("selectionMaximumCredit", #"最高\s*([0-9]+(?:\.[0-9]+)?)"#),
            ("earnedCredit", #"已获得学分\s*([0-9]+(?:\.[0-9]+)?)"#),
            ("yxxfs", #"本学期已选学分\s*([0-9]+(?:\.[0-9]+)?)"#)
        ]
        for (key, pattern) in creditPatterns
        {
            if let value = firstCaptures(for: pattern, in: text)?.first, !value.isEmpty
            {
                values[key] = value
            }
        }

        // `yxxfs` 常由前端异步更新，优先读取带固定 id 的元素，避免正文中旧值覆盖它。
        let selectedCreditElement = #"(?is)<[^>]+\bid\s*=\s*['\"]yxxfs['\"][^>]*>(.*?)</[^>]+>"#
        if let content = firstCaptures(for: selectedCreditElement, in: html)?.first
        {
            let value = visibleText(from: content)
            if !value.isEmpty { values["yxxfs"] = value }
        }

        let countdownPattern = #"距选课结束还(?:剩|有)\s*[0-9]+\s*(?:天|小时|分钟)"#
        if let countdown = matches(for: countdownPattern, in: text).first
        {
            values["selectionCountdownText"] = countdown
        }

        // 正方不同模板对“结束时间”变量的命名不一致。只接受名称中明确表达结束的
        // 字段，并把解析留给 CourseSelectionOverview；不会把开始时间误作截止时间。
        let deadlineNames = ["xkjssj", "xk_jssj", "jssj", "jzsj", "endTime", "end_time", "endDate", "sysj"]
        for name in deadlineNames
        {
            let escapedName = NSRegularExpression.escapedPattern(for: name)
            let patterns = [
                "(?is)(?:var|let|const)?\\s*\(escapedName)\\s*[:=]\\s*(?:new\\s+Date\\s*\\()?\\s*['\"]([^'\"]+)['\"]",
                "(?is)\\$\\(\\s*['\"]#\(escapedName)['\"]\\s*\\)\\s*\\.val\\(\\s*['\"]([^'\"]+)['\"]"
            ]
            for pattern in patterns
            {
                if let value = firstCaptures(for: pattern, in: html)?.first,
                   !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                {
                    values[name] = value
                    break
                }
            }
        }
        return values
    }

    private static func visibleText(from html: String) -> String
    {
        let withoutBreaks = html
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "<br>", with: " ")
            .replacingOccurrences(of: "<br/>", with: " ")
            .replacingOccurrences(of: "<br />", with: " ")
        let withoutTags = withoutBreaks.replacingOccurrences(
            of: #"(?is)<[^>]+>"#,
            with: " ",
            options: .regularExpression
        )
        return withoutTags
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func attribute(_ name: String, in tag: String) -> String?
    {
        let escaped = NSRegularExpression.escapedPattern(for: name)
        let pattern = "(?is)(?:^|\\s)\(escaped)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>]+))"
        guard let captures = firstCaptures(for: pattern, in: tag) else { return nil }
        return captures.first(where: { !$0.isEmpty })
    }

    private static func matches(for pattern: String, in text: String) -> [String]
    {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex ..< text.endIndex, in: text)
        return expression.matches(in: text, range: range).compactMap
        { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }
    }

    private static func firstCaptures(for pattern: String, in text: String) -> [String]?
    {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        let searchRange = NSRange(text.startIndex ..< text.endIndex, in: text)
        guard let match = expression.firstMatch(in: text, range: searchRange) else { return nil }
        return (1 ..< match.numberOfRanges).compactMap
        { index in
            let range = match.range(at: index)
            guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else { return nil }
            return String(text[swiftRange])
        }
    }
}

enum CourseSelectionJSON
{
    static func object(from data: Data, operation: String) throws -> Any
    {
        do
        {
            return try JSONSerialization.jsonObject(with: data, options: [])
        }
        catch
        {
            throw CourseSelectionServiceError.invalidResponse(operation)
        }
    }

    static func catalogRows(in value: Any) -> [[String: Any]]
    {
        rows(in: value, rowKeys: ["kcmc", "kch_id", "kch"], containerKeys: ["tmpList", "data", "rows", "items", "content", "result"])
    }

    static func classRows(in value: Any) -> [[String: Any]]
    {
        rows(in: value, rowKeys: ["jxb_id", "jxbmc", "do_jxb_id", "jxb_ids"], containerKeys: ["tmpList", "jxbList", "data", "rows", "items", "content", "result"])
    }

    /// 尝试读取目录响应里的总记录数。不同版本可能把它放在顶层或 queryModel 中；
    /// 没有总数时由调用方按“本段是否返回满 10 条”判断是否继续触底加载。
    static func totalResult(in value: Any) -> Int?
    {
        guard let object = value as? [String: Any] else { return nil }
        for key in ["totalResult", "totalCount", "total", "recordsTotal"]
        {
            if let total = integerValue(object[key]), total >= 0
            {
                return total
            }
        }
        for key in ["queryModel", "pageable", "pagination"]
        {
            if let nested = object[key], let total = totalResult(in: nested)
            {
                return total
            }
        }
        return nil
    }

    static func string(in row: [String: Any], keys: [String]) -> String
    {
        for key in keys
        {
            guard let rawValue = row[key] else { continue }
            let value: String
            switch rawValue
            {
            case let string as String:
                value = string
            case let number as NSNumber:
                value = number.stringValue
            default:
                continue
            }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return ""
    }

    static func integer(in row: [String: Any], keys: [String], defaultValue: Int) -> Int
    {
        Int(string(in: row, keys: keys)) ?? defaultValue
    }

    private static func integerValue(_ value: Any?) -> Int?
    {
        switch value
        {
        case let number as NSNumber:
            return number.intValue
        case let string as String:
            return Int(string.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            return nil
        }
    }

    static func courseName(_ rawValue: String) -> String
    {
        var value = displayText(rawValue)
        if let range = value.range(of: #"^\([^)]*\)"#, options: .regularExpression)
        {
            value.removeSubrange(range)
        }
        if let range = value.range(of: #"\s*简介\s*-\s*[^-]+\s*$"#, options: .regularExpression)
        {
            value.removeSubrange(range)
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func displayText(_ rawValue: String) -> String
    {
        rawValue
            // 教务接口把多段上课时间 / 地点直接放进 HTML 字符串；转换成换行后
            // SwiftUI 会自然排版，不会把 `<br/>` 原样泄露给用户。
            .replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: #"[ \t]*\n[ \t]*"#, with: "\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func teacherName(_ rawValue: String) -> String
    {
        rawValue
            .split(separator: ";", omittingEmptySubsequences: true)
            .map(String.init)
            .map
            { item in
                let parts = item.split(separator: "/", omittingEmptySubsequences: false)
                return parts.count >= 2 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : item.trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty }
            .joined(separator: "、")
    }

    static func childSelectionTokens(from row: [String: Any], parentToken: String) -> [String]
    {
        // 不同页面模板可能把 token 放在 data-* 字段或 onclick 中；全部只解析
        // 服务端返回的长十六进制 token，绝不从 jxb_id / 课程号推导。
        let rawTokens = [
            "do_jxb_id", "dojxbid", "doJxbId", "jxb_ids", "jxbids",
            "data_do_jxb_id", "data_jxb_ids", "onclick", "operation", "operate"
        ].compactMap { row[$0] }.compactMap(scalarString)
        var tokens: [String] = []
        for rawToken in rawTokens where !rawToken.isEmpty
        {
            for token in longHexTokens(in: rawToken)
            {
                if !tokens.contains(token)
                {
                    tokens.append(token)
                }
            }
        }
        guard !tokens.isEmpty, !(tokens.count == 1 && tokens[0] == parentToken) else { return [] }
        if tokens.contains(parentToken)
        {
            return [parentToken] + tokens.filter { $0 != parentToken }
        }
        return [parentToken] + tokens
    }

    private static func scalarString(_ value: Any) -> String?
    {
        switch value
        {
        case let string as String:
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    private static func longHexTokens(in value: String) -> [String]
    {
        let pattern = #"(?i)(?<![0-9a-f])[0-9a-f]{48,}(?![0-9a-f])"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(value.startIndex ..< value.endIndex, in: value)
        return expression.matches(in: value, range: range).compactMap
        { match in
            guard let tokenRange = Range(match.range, in: value) else { return nil }
            return String(value[tokenRange])
        }
    }

    private static func rows(in value: Any, rowKeys: [String], containerKeys: [String]) -> [[String: Any]]
    {
        if let rows = value as? [[String: Any]]
        {
            return rows
        }
        // `JSONSerialization` 在不同系统版本上可能桥接为 [Any] / NSArray，而不是
        // 直接可转换的 [[String: Any]]。主教学班接口恰好会返回顶层数组，因此逐项
        // 桥接一次，避免合法的三条教学班记录被误判成“无法识别”。
        if let values = value as? [Any]
        {
            let rows = values.compactMap { item -> [String: Any]? in
                if let row = item as? [String: Any] { return row }
                if let dictionary = item as? NSDictionary { return dictionary as? [String: Any] }
                return nil
            }
            if !rows.isEmpty { return rows }
        }
        guard let object = value as? [String: Any] else { return [] }
        if rowKeys.contains(where: { object[$0] != nil })
        {
            return [object]
        }
        for key in containerKeys
        {
            guard let nestedValue = object[key] else { continue }
            let nestedRows = rows(in: nestedValue, rowKeys: rowKeys, containerKeys: containerKeys)
            if !nestedRows.isEmpty { return nestedRows }
        }
        return []
    }
}

extension String
{
    func ifEmpty(_ fallback: String) -> String
    {
        isEmpty ? fallback : self
    }
}
