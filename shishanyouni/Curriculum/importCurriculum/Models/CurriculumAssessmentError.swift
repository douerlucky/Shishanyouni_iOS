import Foundation

enum CurriculumAssessmentError: LocalizedError
{
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingFailed(Error)

    var errorDescription: String?
    {
        switch self
        {
        case .invalidURL:
            return "考核方式查询地址无效。"
        case .invalidResponse:
            return "考核方式查询返回了无法识别的响应。"
        case let .httpError(code):
            return "考核方式查询失败（状态码 \(code)）。"
        case let .decodingFailed(error):
            return "考核方式数据解析失败：\(error.localizedDescription)"
        }
    }
}
