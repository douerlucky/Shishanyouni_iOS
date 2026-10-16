//
//  CurriculumAPIModels.swift
//  shishanyouni
//
//  课表请求、课表响应与教务考核方式响应。
//  这里只定义接口的数据格式；请求执行、错误处理和界面状态留在业务模块。
//

import Foundation

// MARK: - 课表请求

// token 为 nil 时不编码该字段，保持原有的未绑定请求行为。
struct TimetableRequest: Encodable
{
    let username: String
    let password: String
    let token: String?
    let type: Int = 0
    let year: String
    let term: String
}

// MARK: - 课表接口响应

/// 服务端课表单条记录。
///
/// 这个类型只负责兼容不同接口字段名；转换成 App 中使用的 `Course` 后，
/// 其余界面不应再依赖服务端字段细节。
struct TimetableModel: Decodable
{
    let name: String
    let room: String?
    let teacher: String?
    let weekList: [Int]
    let start: Int
    let step: Int
    let day: Int
    let term: String?
    let colorRandom: Int
    let weeks: String?
    let time: String?
    /// 教务接口可能直接返回的考核方式（考试、考查或未安排）。
    let assessmentMethod: String?

    private enum CodingKeys: String, CodingKey
    {
        case name, room, teacher, weekList, weeks, week
        case start, period, step, length, day, term, colorRandom, time, khfsmc
    }

    init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        room = try container.decodeIfPresent(String.self, forKey: .room)
        teacher = try container.decodeIfPresent(String.self, forKey: .teacher)
        weekList = try container.decodeIfPresent([Int].self, forKey: .weekList) ?? []
        start = try container.decodeIfPresent(Int.self, forKey: .start)
            ?? container.decodeIfPresent(Int.self, forKey: .period) ?? 1
        step = try container.decodeIfPresent(Int.self, forKey: .step)
            ?? container.decodeIfPresent(Int.self, forKey: .length) ?? 1
        day = try container.decode(Int.self, forKey: .day)
        term = try container.decodeIfPresent(String.self, forKey: .term)
        colorRandom = try container.decodeIfPresent(Int.self, forKey: .colorRandom) ?? abs(name.hashValue % 32)
        weeks = try container.decodeIfPresent(String.self, forKey: .week)
        time = try container.decodeIfPresent(String.self, forKey: .time)
        assessmentMethod = try container.decodeIfPresent(String.self, forKey: .khfsmc)
    }
}

/// 课表接口的数据体；兼容 `timetableModels` 与旧字段 `timeTable`。
struct TimetableData: Decodable
{
    let timetableModels: [TimetableModel]
    let others: [String]?
    let startDate: String?
    let loadTime: Int64?

    private enum CodingKeys: String, CodingKey
    {
        case timetableModels, timeTable, others, startDate, loadTime
    }

    init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timetableModels = try container.decodeIfPresent([TimetableModel].self, forKey: .timetableModels)
            ?? container.decodeIfPresent([TimetableModel].self, forKey: .timeTable) ?? []
        others = try container.decodeIfPresent([String].self, forKey: .others)
        startDate = try container.decodeIfPresent(String.self, forKey: .startDate)
        loadTime = try container.decodeIfPresent(Int64.self, forKey: .loadTime)
    }
}

/// 课表接口顶层响应。
struct TimetableResponse: Decodable
{
    let msg: String?
    let code: Int
    let data: TimetableData?

    var isSuccess: Bool { code == 200 || code == 2 }
}

// MARK: - 教务课程考核方式

/// 教务「我的课表（学生）」接口中的单条课次。
///
/// 这个接口与狮山有你自己的课表接口不同：它带有 `khfsmc`，因此只用来
/// 补充考核方式，不参与课程时间、地点等主数据的解析。
struct CurriculumAssessmentItem: Decodable
{
    let courseName: String?
    let teachingClassName: String?
    let assessmentMethod: String?

    private enum CodingKeys: String, CodingKey
    {
        case courseName = "kcmc"
        case teachingClassName = "jxbmc"
        case assessmentMethod = "khfsmc"
    }
}

struct CurriculumAssessmentResponse: Decodable
{
    let kbList: [CurriculumAssessmentItem]?
}
