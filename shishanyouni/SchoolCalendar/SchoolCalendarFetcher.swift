//
//  SchoolCalendarFetcher.swift
//  shishanyouni
//

import Foundation

final class SchoolCalendarFetcher
{
    static let shared = SchoolCalendarFetcher()

    /// 教务系统校历页会将活动内嵌在 `rc.push(...)` 脚本中，而不是返回 JSON。
    private let pageURL = "http://byjxyt.hzau.edu.cn/pkgl/xlglMobile_cxXlIndexForxs.html"

    private static let dateFormatter: DateFormatter =
    {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private init() {}

    func fetchSchoolCalendar(cookie: String) async throws -> [SchoolCalendarEvent]
    {
        let html = try await fetchPageHTML(cookie: cookie)
        let events = Self.parseEmbeddedCalendarEvents(from: html)

        guard !events.isEmpty else
        {
            throw SchoolCalendarFetcherError.unrecognizableActivityData
        }

        print("📅 校历页面解析完成：\(events.count) 条")
        return events
    }

    private func fetchPageHTML(cookie: String) async throws -> String
    {
        // 必须复现浏览器成功的基础 GET 请求；该页面不支持 doType=query 这类猜测参数。
        guard let url = URL(string: pageURL) else
        {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/152.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue(cookie, forHTTPHeaderField: "Cookie")

        let (data, response) = try await NetworkService.perform(request: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else
        {
            throw NSError(domain: "HTTPError", code: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }

        guard let html = String(data: data, encoding: .utf8) else
        {
            throw URLError(.cannotDecodeContentData)
        }

        // HTTP 200 也可能是登录失效后的异常页；不要把它当作空校历静默吞掉。
        guard html.contains("rc.push") else
        {
            throw SchoolCalendarFetcherError.invalidCalendarPage
        }

        return html
    }

    /// 解析学校页面中的 `rc.push({ bgdate, eddate, title, bzinfo })` 活动对象。
    /// 设为内部可见，便于测试用真实响应格式防回归。
    static func parseEmbeddedCalendarEvents(from html: String) -> [SchoolCalendarEvent]
    {
        let pattern = "rc\\s*\\.\\s*push\\s*\\(\\s*\\{(.*?)\\}\\s*\\)\\s*;?"
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.dotMatchesLineSeparators]
        ) else
        {
            return []
        }

        let fullRange = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex.matches(in: html, range: fullRange)

        return matches.compactMap
        { match in
            guard let entryRange = Range(match.range(at: 1), in: html) else
            {
                return nil
            }

            let entry = String(html[entryRange])
            guard let startDateString = javaScriptStringValue(for: "bgdate", in: entry),
                  let title = javaScriptStringValue(for: "title", in: entry),
                  let startDate = dateFormatter.date(from: startDateString) else
            {
                return nil
            }

            let endDate = javaScriptStringValue(for: "eddate", in: entry)
                .flatMap { dateFormatter.date(from: $0) }
            let description = javaScriptStringValue(for: "bzinfo", in: entry)

            return SchoolCalendarEvent(
                title: title,
                startDate: startDate,
                endDate: endDate == startDate ? nil : endDate,
                type: eventType(for: title),
                description: description
            )
        }
        .sorted { $0.startDate < $1.startDate }
    }

    private static func javaScriptStringValue(for field: String, in entry: String) -> String?
    {
        let escapedField = NSRegularExpression.escapedPattern(for: field)
        let pattern = "\\b\(escapedField)\\s*:\\s*(['\"])((?:\\\\.|[^\\\\])*?)\\1"
        guard let regex = try? NSRegularExpression(pattern: pattern) else
        {
            return nil
        }

        let fullRange = NSRange(entry.startIndex..<entry.endIndex, in: entry)
        guard let match = regex.firstMatch(in: entry, range: fullRange),
              let valueRange = Range(match.range(at: 2), in: entry) else
        {
            return nil
        }

        return decodeJavaScriptEscapes(String(entry[valueRange]))
    }

    private static func decodeJavaScriptEscapes(_ value: String) -> String
    {
        var result = ""
        var index = value.startIndex

        while index < value.endIndex
        {
            let character = value[index]
            guard character == "\\" else
            {
                result.append(character)
                index = value.index(after: index)
                continue
            }

            let escapedIndex = value.index(after: index)
            guard escapedIndex < value.endIndex else
            {
                result.append(character)
                break
            }

            switch value[escapedIndex]
            {
            case "n": result.append("\n")
            case "r": result.append("\r")
            case "t": result.append("\t")
            case "\\": result.append("\\")
            case "\"": result.append("\"")
            case "'": result.append("'")
            default:
                result.append("\\")
                result.append(value[escapedIndex])
            }

            index = value.index(after: escapedIndex)
        }

        return result
    }

    private static func eventType(for title: String) -> SchoolEventType
    {
        if title.contains("开学") || title.contains("上课")
        {
            return .trimesterStart
        }
        if title.contains("学期结束") || title.contains("暑假") || title.contains("寒假")
        {
            return .trimesterEnd
        }
        if title.contains("考试") || title.contains("考")
        {
            return .exam
        }
        if title.contains("节") || title.contains("假")
        {
            return .holiday
        }
        if title.contains("运动会") || title.contains("活动") || title.contains("动")
        {
            return .activity
        }
        return .other
    }
}

private enum SchoolCalendarFetcherError: LocalizedError
{
    case invalidCalendarPage
    case unrecognizableActivityData

    var errorDescription: String?
    {
        switch self
        {
        case .invalidCalendarPage:
            return "校历页面未返回活动数据，请重新登录后再试"
        case .unrecognizableActivityData:
            return "校历页面返回了活动，但格式无法识别"
        }
    }
}
