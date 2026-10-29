import Foundation

/// 两种导入来源共用的纯文本周次解析，不发起网络请求，也不依赖某个导入器。
enum CurriculumWeekParser
{
    static func parse(_ text: String) -> [Int]
    {
        var result = Set<Int>()
        let normalized = text.replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "、", with: ",")
        for segment in normalized.split(separator: ",")
        {
            let value = String(segment).replacingOccurrences(of: #"\s|周|[()（）]|单|双"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: "－", with: "-")
                .replacingOccurrences(of: "~", with: "-")
            let bounds = value.split(separator: "-", omittingEmptySubsequences: false)
            guard (1 ... 2).contains(bounds.count), let firstText = bounds.first, let lastText = bounds.last,
                  let first = Int(firstText), let last = Int(lastText),
                  first > 0, last >= first, last <= 60 else { return [] }
            for week in first ... last
            {
                if segment.contains("单") && week.isMultiple(of: 2) { continue }
                if segment.contains("双") && !week.isMultiple(of: 2) { continue }
                result.insert(week)
            }
        }
        return result.sorted()
    }
}
