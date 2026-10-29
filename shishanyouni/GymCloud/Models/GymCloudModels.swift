import Foundation

enum NanhuRunQuerySource: String, QuerySourceOption
{
    case cas = "cas"
    case shishanyouni = "shishanyouni"

    var id: String { rawValue }

    var title: String
    {
        switch self
        {
        case .cas:
            return SchoolServiceName.sportsCloud
        case .shishanyouni:
            return "狮山有你"
        }
    }
}

// 环湖跑成绩数据结构
struct RunScore: Identifiable, Codable
{
    var id: String { "\(schoolYear)-\(semester)" }
    let schoolYear: String // 学年
    let semester: String // 学期
    let count: String // 环湖跑次数/圈数
}

// 体测成绩详情
struct PhysicalDetail: Codable
{
    let project: String // 项目名称
    let result: String // 成绩
    let score: String // 得分
    let grade: String // 等级
}

// 体测年度汇总
struct PhysicalScore: Identifiable, Codable
{
    var id: String { testYear }
    let testYear: String // 测试年度
    let updateTime: String // 最后更新
    let totalScore: String // 总分
    let totalGrade: String // 总等级
    let gradeLevel: String // 年级（大一/大二...）
    let className: String // 班级
    let height: String // 身高
    let weight: String // 体重
    var details: [PhysicalDetail] = []
}

// 南湖跑接口响应位于 GymCloud/Models/GymCloudAPIModels.swift。

enum NanhuRunQueryError: LocalizedError
{
    case invalidURL
    case invalidResponse
    case apiError(String)

    var errorDescription: String?
    {
        switch self
        {
        case .invalidURL:
            return "南湖跑查询地址无效。"
        case .invalidResponse:
            return "南湖跑查询返回了无法识别的响应。"
        case let .apiError(message):
            return message
        }
    }
}
