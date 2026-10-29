import Foundation

// 馆藏接口模型位于 LibraryCatalogSearch/Models/LibraryAPIModels.swift。

enum LibraryCatalogError: LocalizedError
{
    case invalidResponse
    case httpStatus(Int)
    case server(message: String)

    var errorDescription: String?
    {
        switch self
        {
        case .invalidResponse:
            return "馆藏接口返回了无法识别的数据。"

        case let .httpStatus(statusCode):
            return "馆藏接口请求失败（HTTP \(statusCode)）。"

        case let .server(message):
            return message
        }
    }
}
