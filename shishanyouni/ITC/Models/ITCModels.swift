import Foundation

struct ITC_Course: Identifiable
{
    let courseID: String
    let name: String

    var id: String { courseID }
}

struct ITC_Assignment: Identifiable
{
    let courseID: String
    let assignID: String
    let assignName: String
    let isCurrent: Bool
    var ddlTime: String?
    var fullGrade: String?
    var allQuestionsCount: String?
    var questionList: [ITC_Question]?

    var id: String { assignID }

    var finalScore: String
    {
        guard let list = questionList, !list.isEmpty else { return "-" }
        // 只有编程题（有评判结果/测试数据）才计入实际得分
        let programmingQuestions = list.filter { $0.isProgramming }
        guard !programmingQuestions.isEmpty else { return "-" }
        let total = programmingQuestions.reduce(0.0)
        { sum, q in
            if let g = Double(q.grade), q.grade != "-" { return sum + g }
            return sum
        }
        return String(format: "%.1f", total)
    }

    var completedCount: Int
    {
        questionList?.filter { $0.hasSubmitted }.count ?? 0
    }

    var totalQuestionCount: Int
    {
        questionList?.count ?? 0
    }
}

struct ITC_Question: Identifiable
{
    let name: String
    let sectionType: String   // 题型区块名，如"多选题"/"判断题"/"编程题"
    let questionFullGrade: String
    let firstSubmitTime: String
    let lastUpdate: String
    let grade: String
    let submittedByBadge: Bool  // <span>已提交</span> badge 方式标记
    let testData: [ITC_TestData]

    var id: String { name }

    // 编程题：有测试数据（有「评判结果」字样）才是编程题，其余题型不计得分
    var isProgramming: Bool { !testData.isEmpty }

    var hasSubmitted: Bool
    {
        if submittedByBadge { return true }
        if !grade.isEmpty && grade != "-" { return true }
        if !firstSubmitTime.isEmpty && firstSubmitTime != "-" { return true }
        if !lastUpdate.isEmpty && lastUpdate != "-" { return true }
        return false
    }

    var isReportType: Bool
    {
        !firstSubmitTime.isEmpty && firstSubmitTime != "-"
    }
}

struct ITC_TestData: Identifiable
{
    let dataID: String
    let correctStatus: String

    var id: String { dataID }

    var isCorrect: Bool { correctStatus.contains("正确") }
}

enum ITCError: LocalizedError
{
    case executionNotFound
    case loginFailed(String)
    case noLocation
    case cookieNotFound
    case parseFailed
    case networkError(String)
    case notLoggedIn

    var errorDescription: String?
    {
        switch self
        {
        case .executionNotFound:
            return "未获取到\(SchoolServiceName.unifiedIdentity)登录凭据。"
        case let .loginFailed(msg):
            return msg
        case .noLocation:
            return "\(SchoolServiceName.unifiedIdentity)登录后未获取到跳转地址。"
        case .cookieNotFound:
            return "未获取到Session Cookie。"
        case .parseFailed:
            return "课程列表解析失败。"
        case let .networkError(msg):
            return msg
        case .notLoggedIn:
            return "尚未登录，请先获取课程列表完成登录。"
        }
    }
}
