//
//  SchoolCalendarFetcher.swift
//  shishanyouni
//

import Foundation

class SchoolCalendarFetcher {
    static let shared = SchoolCalendarFetcher()
    
    private let pageURL = "http://byjxyt.hzau.edu.cn/pkgl/xlglMobile_cxXlIndexForxs.html"
    
    private let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt
    }()
    
    private let altDateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "yyyy/MM/dd"
        return fmt
    }()
    
    private init() {}
    
    func fetchSchoolCalendar(cookie: String, xnm: String, xqm: String) async throws -> [SchoolCalendarEvent] {
        // 策略1: 直接 GET 页面 HTML，校历可能本身就是查询展示页
        if let events = try? await fetchPageHTML(cookie: cookie), !events.isEmpty {
            return events
        }
        
        // 策略2: POST doType=query（标准正方教务 JSON 查询）
        if let events = try? await fetchViaQuery(cookie: cookie, xnm: xnm, xqm: xqm), !events.isEmpty {
            return events
        }
        
        // 策略3: 尝试不同 xqm（1/2 而非 3/12）
        let altXqm = xqm == "3" ? "1" : "2"
        if altXqm != xqm,
           let events = try? await fetchViaQuery(cookie: cookie, xnm: xnm, xqm: altXqm), !events.isEmpty {
            return events
        }
        
        // 策略4: 不传 xqm，仅传 xnm
        if let events = try? await fetchViaQuery(cookie: cookie, xnm: xnm, xqm: nil), !events.isEmpty {
            return events
        }
        
        return []
    }
    
    // MARK: - 策略1：获取页面 HTML
    
    private func fetchPageHTML(cookie: String) async throws -> [SchoolCalendarEvent] {
        let urlString = "\(pageURL)?gnmkdm=Y210501&layout=default"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "URLError", code: 400)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        
        let (data, response) = try await NetworkService.perform(request: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "HTTPError", code: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        
        guard let html = String(data: data, encoding: .utf8) else {
            return []
        }
        
        print("📅 校历HTML页面(前800字符): \(html.prefix(800))")
        
        return parseHTMLCalendar(html)
    }
    
    // MARK: - 策略2：POST JSON 查询
    
    private func fetchViaQuery(cookie: String, xnm: String, xqm: String?) async throws -> [SchoolCalendarEvent] {
        let urlString = "\(pageURL)?doType=query&gnmkdm=Y210501"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "URLError", code: 400)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue("\(pageURL)?gnmkdm=Y210501&layout=default", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        
        var params: [String: String] = ["xnm": xnm]
        if let xqm = xqm {
            params["xqm"] = xqm
        }
        params["queryModel.showCount"] = "100"
        params["queryModel.currentPage"] = "1"
        
        request.httpBody = params
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await NetworkService.perform(request: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "HTTPError", code: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        
        let jsonString = String(data: data, encoding: .utf8) ?? ""
        print("📅 校历JSON查询响应(前500字符): \(jsonString.prefix(500))")
        
        return try parseJSONOrHTML(data: data)
    }
    
    // MARK: - 解析
    
    private func parseJSONOrHTML(data: Data) throws -> [SchoolCalendarEvent] {
        // 尝试 JSON 解析
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // items 数组
            if let items = json["items"] as? [[String: Any]], !items.isEmpty {
                return parseJSONItems(items)
            }
            // 直接就是数组
            if let items = json as? [[String: Any]] {
                return parseJSONItems(items)
            }
            // rows / data 等其他字段名
            for key in ["rows", "data", "list", "records"] {
                if let items = json[key] as? [[String: Any]], !items.isEmpty {
                    return parseJSONItems(items)
                }
            }
        }
        
        // 尝试 HTML 解析
        if let html = String(data: data, encoding: .utf8) {
            return parseHTMLCalendar(html)
        }
        
        return []
    }
    
    private func parseJSONItems(_ items: [[String: Any]]) -> [SchoolCalendarEvent] {
        var events: [SchoolCalendarEvent] = []
        
        for dict in items {
            let allKeys = Set(dict.keys)
            
            // 查找日期字段（尝试各种可能的字段名）
            let startDate: Date? = {
                for key in ["ksrq", "kssj", "startDate", "beginDate", "rq", "jxrl", "kcrq"] {
                    if let str = dict[key] as? String,
                       let d = dateFormatter.date(from: str) ?? altDateFormatter.date(from: str) {
                        return d
                    }
                }
                return nil
            }()
            
            let endDate: Date? = {
                for key in ["jsrq", "jssj", "endDate", "finishDate", "jxjsrq"] {
                    if let str = dict[key] as? String,
                       let d = dateFormatter.date(from: str) ?? altDateFormatter.date(from: str) {
                        return d
                    }
                }
                return nil
            }()
            
            let title: String = {
                for key in ["xlmc", "sjmc", "title", "name", "mc", "xmmc", "xlMc"] {
                    if let t = dict[key] as? String, !t.isEmpty { return t }
                }
                return "未知事件"
            }()
            
            let description: String? = {
                for key in ["bz", "description", "note", "remark", "sm"] {
                    if let t = dict[key] as? String, !t.isEmpty { return t }
                }
                return nil
            }()
            
            guard let date = startDate else { continue }
            
            let type: SchoolEventType = {
                let lower = title.lowercased()
                if lower.contains("假") || lower.contains("节") { return .holiday }
                if lower.contains("试") || lower.contains("考") { return .exam }
                if lower.contains("开学") || lower.contains("上课") { return .trimesterStart }
                if lower.contains("结束") || lower.contains("放假") || lower.contains("暑假") || lower.contains("寒假") { return .trimesterEnd }
                if lower.contains("动") || lower.contains("活动") { return .activity }
                return .other
            }()
            
            events.append(SchoolCalendarEvent(
                title: title,
                startDate: date,
                endDate: endDate,
                type: type,
                description: description
            ))
        }
        
        return events
    }
    
    private func parseHTMLCalendar(_ html: String) -> [SchoolCalendarEvent] {
        var events: [SchoolCalendarEvent] = []
        
        // 多种日期匹配模式
        let datePatterns = [
            // yyyy-MM-dd
            #"\b(\d{4}-\d{2}-\d{2})\b"#,
            // yyyy/MM/dd
            #"\b(\d{4}/\d{2}/\d{2})\b"#,
            // MM月dd日
            #"(\d{1,2})月(\d{1,2})日"#,
        ]
        
        // 模式1: 表格行 <tr> ... </tr> 中包含日期
        let trPattern = #"<tr[^>]*>(.*?)</tr>"#
        if let trRegex = try? NSRegularExpression(pattern: trPattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) {
            let nsString = html as NSString
            let trMatches = trRegex.matches(in: html, range: NSRange(location: 0, length: nsString.length))
            
            for trMatch in trMatches {
                let rowHTML = nsString.substring(with: trMatch.range(at: 1))
                
                // 在行内找日期
                var foundDate: Date?
                var foundTitle: String?
                
                for datePattern in datePatterns {
                    if let dateRegex = try? NSRegularExpression(pattern: datePattern, options: []) {
                        let dateRange = dateRegex.rangeOfFirstMatch(in: rowHTML, range: NSRange(location: 0, length: rowHTML.utf16.count))
                        if dateRange.location != NSNotFound {
                            var dateStr = (rowHTML as NSString).substring(with: dateRange)
                            // 处理 MM月DD日 格式
                            if datePattern.contains("月") {
                                let parts = dateStr.components(separatedBy: CharacterSet(charactersIn: "月日"))
                                if parts.count >= 2, let m = Int(parts[0]), let d = Int(parts[1]) {
                                    let now = Date()
                                    let cal = Calendar.current
                                    let year = cal.component(.year, from: now)
                                    var comps = DateComponents(year: year, month: m, day: d)
                                    foundDate = cal.date(from: comps)
                                }
                            } else {
                                if dateStr.contains("/") {
                                    foundDate = altDateFormatter.date(from: dateStr)
                                } else {
                                    foundDate = dateFormatter.date(from: dateStr)
                                }
                            }
                            break
                        }
                    }
                }
                
                // 提取 <td> 内的文本作为事件标题
                let tdPattern = #"<td[^>]*>([^<]*)</td>"#
                if let tdRegex = try? NSRegularExpression(pattern: tdPattern, options: [.dotMatchesLineSeparators]),
                   let tdMatch = tdRegex.firstMatch(in: rowHTML, range: NSRange(location: 0, length: rowHTML.utf16.count)) {
                    foundTitle = (rowHTML as NSString).substring(with: tdMatch.range(at: 1))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                if let date = foundDate, let title = foundTitle, !title.isEmpty, !title.hasPrefix("<") {
                    let type: SchoolEventType = {
                        let lower = title
                        if lower.contains("假") || lower.contains("节") { return .holiday }
                        if lower.contains("试") || lower.contains("考") { return .exam }
                        if lower.contains("开学") || lower.contains("上课") { return .trimesterStart }
                        if lower.contains("结束") || lower.contains("放假") { return .trimesterEnd }
                        return .other
                    }()
                    
                    events.append(SchoolCalendarEvent(title: title, startDate: date, type: type))
                }
            }
        }
        
        // 模式2: 直接在 HTML 中搜索日期 + 事件配对
        if events.isEmpty {
            for datePattern in datePatterns {
                if let dateRegex = try? NSRegularExpression(pattern: datePattern, options: []),
                   let eventRegex = try? NSRegularExpression(pattern: #"([\u4e00-\u9fff]{2,20}(?:假期|节日|周|考试|开学|放假|暑假|寒假))"#, options: []) {
                    
                    let nsString = html as NSString
                    let dateMatches = dateRegex.matches(in: html, range: NSRange(location: 0, length: nsString.length))
                    let eventMatches = eventRegex.matches(in: html, range: NSRange(location: 0, length: nsString.length))
                    
                    for dateMatch in dateMatches {
                        var dateStr = nsString.substring(with: dateMatch.range(at: 1))
                        var date: Date?
                        
                        if dateStr.contains("月") {
                            let parts = dateStr.components(separatedBy: CharacterSet(charactersIn: "月日"))
                            if parts.count >= 2, let m = Int(parts[0]), let d = Int(parts[1]) {
                                let now = Date()
                                let cal = Calendar.current
                                var comps = DateComponents(year: cal.component(.year, from: now), month: m, day: d)
                                date = cal.date(from: comps)
                            }
                        } else if dateStr.contains("/") {
                            date = altDateFormatter.date(from: dateStr)
                        } else {
                            date = dateFormatter.date(from: dateStr)
                        }
                        
                        // 找最近的 event
                        if let date = date {
                            let dateLocation = dateMatch.range.location
                            var closestEvent: String?
                            var closestDist = Int.max
                            
                            for eventMatch in eventMatches {
                                let dist = abs(eventMatch.range.location - dateLocation)
                                if dist < 200 && dist < closestDist {
                                    closestEvent = nsString.substring(with: eventMatch.range)
                                    closestDist = dist
                                }
                            }
                            
                            if let evt = closestEvent {
                                let type: SchoolEventType = evt.contains("假") || evt.contains("节") ? .holiday
                                    : evt.contains("考") ? .exam
                                    : evt.contains("开学") ? .trimesterStart
                                    : evt.contains("放假") || evt.contains("暑假") || evt.contains("寒假") ? .trimesterEnd
                                    : .other
                                events.append(SchoolCalendarEvent(title: evt, startDate: date, type: type))
                            }
                        }
                    }
                }
            }
        }
        
        return events
    }
}
