import Foundation

enum GradeExportError: LocalizedError
{
    case noGrades
    case renderFailed
    case photoAccessDenied
    case saveFailed(String)

    var errorDescription: String?
    {
        switch self
        {
        case .noGrades:
            return "请至少勾选一门成绩后再导出。"
        case .renderFailed:
            return "成绩长图生成失败，请稍后重试。"
        case .photoAccessDenied:
            return "没有相册写入权限，请在系统设置中允许访问照片。"
        case .saveFailed(let message):
            return message
        }
    }
}
