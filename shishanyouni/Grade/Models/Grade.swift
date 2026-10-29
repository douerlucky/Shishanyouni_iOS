import Foundation

/// 成绩查询的数据来源。
///
/// 狮山有你接口适合快速查询；教务系统接口会额外返回 `xh_id`、`xnm`、`xqm`，
/// 这些字段正是“成绩明细”接口需要的上下文。
enum GradeQuerySource: String, QuerySourceOption, Codable
{
    case teachingSystem = "teachingSystem"
    case shishanyouni = "shishanyouni"

    var id: String { rawValue }

    var title: String
    {
        switch self
        {
        case .teachingSystem: return SchoolServiceName.teachingSystem
        case .shishanyouni: return "狮山有你"
        }
    }
}

// 成绩接口响应位于 Grade/Models/GradeAPIModels.swift。

struct Grade: Identifiable, Codable
{
    let jxb_id: String
    var id: String { jxb_id }

    let kcmc: String       // 课程名称
    let kcxzmc: String?    // 课程性质（必修 / 选修）
    let xf: String         // 学分
    let cj: String         // 成绩
    let jd: String         // 绩点
    let khfsmc: String?    // 考核方式（考试 / 考查）
    let kcgsmc: String?    // 课程归属名称
    let xm: String?        // 学生姓名
    let bj: String?        // 班级
    let kch: String?       // 课程号
    let jsxm: String?      // 教师姓名
    let kkbmmc: String?    // 开课部门
    let xnmmc: String?     // 学年名称（如 2025-2026）
    let xqmmc: String?     // 学期名称
    let detail: String?
    let bfzcj: String?     // 百分制成绩

    // 下面三个字段只由教务系统成绩接口提供；旧缓存没有这些字段时会自动解码为 nil。
    let xh_id: String?
    var xnm: String?
    var xqm: String?

    /// 旧版缓存没有来源字段，默认按“狮山有你”处理，避免旧成绩突然被当成教务系统成绩。
    var querySource: GradeQuerySource?

    var effectiveQuerySource: GradeQuerySource
    {
        querySource ?? .shishanyouni
    }

}

/// 教务系统成绩组成项，例如“平时成绩 / 期中成绩 / 期末成绩”。
struct GradeComponent: Identifiable, Equatable
{
    let name: String
    let percentageText: String?
    let scoreText: String

    var id: String { "\(name)|\(percentageText ?? "")|\(scoreText)" }

    var percentageValue: Double?
    {
        guard let percentageText else { return nil }
        let number = percentageText.filter { $0.isNumber || $0 == "." }
        return Double(number)
    }

    var scoreValue: Double?
    {
        let number = scoreText.filter { $0.isNumber || $0 == "." }
        return Double(number)
    }

    /// 把百分制分数转换成圆环中 0...1 的填充比例。
    var normalizedScore: Double
    {
        min(max((scoreValue ?? 0) / 100, 0), 1)
    }

    var isOverallScore: Bool
    {
        name.contains("总评") || name.contains("总成绩")
    }
}

enum GradeQueryError: LocalizedError
{
    case invalidURL
    case invalidResponse
    case emptyResponse
    case httpStatus(Int)
    case sessionUnavailable
    case invalidDetailContext
    case invalidDetailHTML

    var errorDescription: String?
    {
        switch self
        {
        case .invalidURL:
            return "成绩查询地址无效。"
        case .invalidResponse:
            return "成绩接口返回了无法识别的响应。"
        case .emptyResponse:
            return "成绩接口返回了空数据。"
        case let .httpStatus(code):
            return code == 901
                ? "教务系统登录状态已失效，请重新查询成绩后再试。"
                : "成绩查询失败，教务系统返回状态码 \(code)。"
        case .sessionUnavailable:
            return "当前没有可用的教务系统会话，请先用“教务系统”数据源查询一次成绩。"
        case .invalidDetailContext:
            return "这门课程缺少成绩明细查询参数。"
        case .invalidDetailHTML:
            return "没有从教务系统响应中解析到成绩明细。"
        }
    }
}
