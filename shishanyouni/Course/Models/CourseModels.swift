import Foundation

enum CourseQuerySource: String, QuerySourceOption
{
    case cas = "cas"
    case shishanyouni = "shishanyouni"

    var id: String { rawValue }

    var title: String
    {
        switch self
        {
        case .cas:
            return SchoolServiceName.academicPlatform
        case .shishanyouni:
            return "狮山有你"
        }
    }
}

// 课程检索接口模型位于 Course/Models/CourseAPIModels.swift。

enum AllCourseQueryError: LocalizedError
{
    case invalidURL
    case invalidResponse
    case apiError(String)

    var errorDescription: String?
    {
        switch self
        {
        case .invalidURL:
            return "课程查询地址无效。"
        case .invalidResponse:
            return "课程查询返回了无法识别的响应。"
        case let .apiError(message):
            return message
        }
    }
}

// MARK: - 统一课程模型

struct CourseInfo: Identifiable, Decodable
{
    let row_id: String
    let kch_id: String
    let kch: String
    let kcmc: String
    let kkbmmc: String?
    let kclbmc: String?
    let xnm: String
    let xqm: String
    let kcxzmc: String?
    let classCode: String?
    let teacherName: String?
    let siteName: String?
    let className: String?
    let querySource: CourseQuerySource

    var id: String
    {
        switch querySource
        {
        case .cas:
            return kch_id
        case .shishanyouni:
            return classCode ?? kch_id
        }
    }

    var displayCode: String?
    {
        guard querySource == .cas else { return nil }
        let trimmed = kch.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private enum CodingKeys: String, CodingKey
    {
        case row_id
        case kch_id
        case kch
        case kcmc
        case kkbmmc
        case kclbmc
        case xnm
        case xqm
        case kcxzmc
    }

    init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        row_id = try container.decode(String.self, forKey: .row_id)
        kch_id = try container.decode(String.self, forKey: .kch_id)
        kch = try container.decode(String.self, forKey: .kch)
        kcmc = try container.decode(String.self, forKey: .kcmc)
        kkbmmc = try container.decodeIfPresent(String.self, forKey: .kkbmmc)
        kclbmc = try container.decodeIfPresent(String.self, forKey: .kclbmc)
        xnm = try container.decode(String.self, forKey: .xnm)
        xqm = try container.decode(String.self, forKey: .xqm)
        kcxzmc = try container.decodeIfPresent(String.self, forKey: .kcxzmc)
        classCode = nil
        teacherName = nil
        siteName = nil
        className = nil
        querySource = .cas
    }

    init(
        row_id: String,
        kch_id: String,
        kch: String,
        kcmc: String,
        kkbmmc: String?,
        kclbmc: String?,
        xnm: String,
        xqm: String,
        kcxzmc: String?,
        classCode: String? = nil,
        teacherName: String? = nil,
        siteName: String? = nil,
        className: String? = nil,
        querySource: CourseQuerySource = .cas
    )
    {
        self.row_id = row_id
        self.kch_id = kch_id
        self.kch = kch
        self.kcmc = kcmc
        self.kkbmmc = kkbmmc
        self.kclbmc = kclbmc
        self.xnm = xnm
        self.xqm = xqm
        self.kcxzmc = kcxzmc
        self.classCode = classCode
        self.teacherName = teacherName
        self.siteName = siteName
        self.className = className
        self.querySource = querySource
    }

    init(from item: LionRubKeywordItem)
    {
        row_id = String(item.id)
        kch_id = item.courseId ?? item.classCode
        kch = item.cno ?? ""
        kcmc = item.cname
        kkbmmc = nil
        kclbmc = nil
        xnm = item.schoolYear
        xqm = item.schoolTerm
        kcxzmc = item.courseNature
        classCode = item.classCode
        teacherName = item.tname
        siteName = item.siteName
        className = item.className
        querySource = .shishanyouni
    }
}

struct CourseClassInfo: Identifiable, Decodable
{
    let jxb_id: String
    let jxbmc: String
    let xm: String?
    let zcmc: String?
    let cdmc: String?
    let zcd: String?
    let xqjmc: String?
    let jc: String?
    let xkrs: String?
    let jxbzc: String?
    let dayNumber: Int?
    let startPeriod: Int?
    let endPeriod: Int?
    let weekNumbers: [Int]?

    var id: String
    {
        "\(jxb_id)_\(xqjmc ?? "")_\(jc ?? "")_\(cdmc ?? "")_\(zcd ?? "")"
    }

    private enum CodingKeys: String, CodingKey
    {
        case jxb_id
        case jxbmc
        case xm
        case zcmc
        case cdmc
        case zcd
        case xqjmc
        case jc
        case xkrs
        case jxbzc
    }

    init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        jxb_id = try container.decode(String.self, forKey: .jxb_id)
        jxbmc = try container.decode(String.self, forKey: .jxbmc)
        xm = try container.decodeIfPresent(String.self, forKey: .xm)
        zcmc = try container.decodeIfPresent(String.self, forKey: .zcmc)
        cdmc = try container.decodeIfPresent(String.self, forKey: .cdmc)
        zcd = try container.decodeIfPresent(String.self, forKey: .zcd)
        xqjmc = try container.decodeIfPresent(String.self, forKey: .xqjmc)
        jc = try container.decodeIfPresent(String.self, forKey: .jc)
        xkrs = try container.decodeIfPresent(String.self, forKey: .xkrs)
        jxbzc = try container.decodeIfPresent(String.self, forKey: .jxbzc)
        dayNumber = nil
        startPeriod = nil
        endPeriod = nil
        weekNumbers = nil
    }

    init(
        jxb_id: String,
        jxbmc: String,
        xm: String?,
        zcmc: String?,
        cdmc: String?,
        zcd: String?,
        xqjmc: String?,
        jc: String?,
        xkrs: String?,
        jxbzc: String?,
        dayNumber: Int? = nil,
        startPeriod: Int? = nil,
        endPeriod: Int? = nil,
        weekNumbers: [Int]? = nil
    )
    {
        self.jxb_id = jxb_id
        self.jxbmc = jxbmc
        self.xm = xm
        self.zcmc = zcmc
        self.cdmc = cdmc
        self.zcd = zcd
        self.xqjmc = xqjmc
        self.jc = jc
        self.xkrs = xkrs
        self.jxbzc = jxbzc
        self.dayNumber = dayNumber
        self.startPeriod = startPeriod
        self.endPeriod = endPeriod
        self.weekNumbers = weekNumbers
    }
}
