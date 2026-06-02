import Foundation

struct LibrarySeatStats
{
    let available: Int
    let inUse: Int
    let notSignedIn: Int
}

class LibraryService
{
    static let shared = LibraryService()
    private let pageURL = "https://libseat.hzau.edu.cn/self"

    func fetchStats() async throws -> LibrarySeatStats
    {
        var request = URLRequest(url: URL(string: pageURL)!)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_6 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await NetworkService.perform(request: request)
        let html = String(data: data, encoding: .utf8) ?? ""

        let stats = parseStats(from: html)
        return stats
    }

    private func parseStats(from html: String) -> LibrarySeatStats
    {
        func extractNumber(after label: String) -> Int
        {
            guard let range = html.range(of: label) else { return 0 }
            let after = html[range.upperBound...]
            var numStr = ""
            var started = false
            for ch in after
            {
                if ch == ">" { started = true; continue }
                if started && ch.isNumber { numStr.append(ch) }
                else if started && !numStr.isEmpty { break }
            }
            return Int(numStr) ?? 0
        }

        let available = extractNumber(after: "当前可用")
        let inUse = extractNumber(after: "已使用")
        let notSignedIn = extractNumber(after: "未签到")
        return LibrarySeatStats(available: available, inUse: inUse, notSignedIn: notSignedIn)
    }
}
