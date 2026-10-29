import Foundation

enum ExamQuerySource: String, QuerySourceOption, Codable {
    case cas = "cas"
    case shishanyouni = "shishanyouni"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cas: return SchoolServiceName.academicPlatform
        case .shishanyouni: return "狮山有你"
        }
    }
}

// 考试接口响应位于 Exam/Models/ExamAPIModels.swift。

enum ExamQueryError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "考试查询地址无效。"
        case .invalidResponse:
            return "考试查询返回了无法识别的响应。"
        case let .apiError(message):
            return message
        }
    }
}

struct Exam: Identifiable, Codable
{
    var id: String {
        if let rowID = rowID {
            return String(rowID)
        }
        return "\(kcmc)_\(ksmc)_\(kssj)"
    }

    private let rowID: Int?
    let kcmc: String
    let ksmc: String
    let kssj: String
    let cdmc: String?
    let zwh: String?
    let xf: String?
    let jxbmc: String?
    let bj: String?
    let querySource: ExamQuerySource

    private enum CodingKeys: String, CodingKey {
        case rowID = "row_id"
        case kcmc
        case ksmc
        case kssj
        case cdmc
        case zwh
        case xf
        case jxbmc
        case bj
        case querySource
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rowID = try container.decodeIfPresent(Int.self, forKey: .rowID)
        kcmc = try container.decode(String.self, forKey: .kcmc)
        ksmc = try container.decode(String.self, forKey: .ksmc)
        kssj = try container.decode(String.self, forKey: .kssj)
        cdmc = try container.decodeIfPresent(String.self, forKey: .cdmc)
        zwh = try container.decodeIfPresent(String.self, forKey: .zwh)
        xf = try container.decodeIfPresent(String.self, forKey: .xf)
        jxbmc = try container.decodeIfPresent(String.self, forKey: .jxbmc)
        bj = try container.decodeIfPresent(String.self, forKey: .bj)
        querySource = try container.decodeIfPresent(ExamQuerySource.self, forKey: .querySource) ?? .cas
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(rowID, forKey: .rowID)
        try container.encode(kcmc, forKey: .kcmc)
        try container.encode(ksmc, forKey: .ksmc)
        try container.encode(kssj, forKey: .kssj)
        try container.encodeIfPresent(cdmc, forKey: .cdmc)
        try container.encodeIfPresent(zwh, forKey: .zwh)
        try container.encodeIfPresent(xf, forKey: .xf)
        try container.encodeIfPresent(jxbmc, forKey: .jxbmc)
        try container.encodeIfPresent(bj, forKey: .bj)
        try container.encode(querySource, forKey: .querySource)
    }

    init(from item: LionExamItem) {
        rowID = nil
        kcmc = item.kcmc
        ksmc = item.ksmc
        kssj = item.kssj
        cdmc = item.cdmc.flatMap { $0.isEmpty ? nil : $0 }
        zwh = nil
        xf = nil
        jxbmc = nil
        bj = item.bj.flatMap { $0.isEmpty ? nil : $0 }
        querySource = .shishanyouni
    }

    var examDate: String
    {
        kssj.components(separatedBy: "(").first ?? kssj
    }

    var examTime: String
    {
        if let time = kssj.components(separatedBy: "(").last
        {
            return time.replacingOccurrences(of: ")", with: "")
        }
        return ""
    }

    var examStartDate: Date? {
        guard let dateText = examDate.firstMatch(of: #"\d{4}-\d{1,2}-\d{1,2}"#) else {
            return nil
        }
        let normalizedTime = examTime
            .replacingOccurrences(of: "－", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
        let parts = normalizedTime
            .components(separatedBy: "-")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard let startTime = parts.first else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: "\(dateText) \(startTime)")
    }

    var seatDisplayText: String {
        if let zwh, !zwh.isEmpty {
            return "座位: \(zwh)"
        }

        switch querySource {
        case .cas:
            return "不支持座位号"
        case .shishanyouni:
            return "不支持座位号"
        }
    }
}

private extension String
{
    func firstMatch(of pattern: String) -> String?
    {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: self, range: NSRange(startIndex..., in: self)),
              let range = Range(match.range, in: self)
        else
        {
            return nil
        }
        return String(self[range])
    }
}
