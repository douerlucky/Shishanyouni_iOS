//
//  LibraryCategoryDetail.swift
//  shishanyouni
//

import Foundation

// 馆藏接口模型位于 LibraryCatalogSearch/Models/LibraryAPIModels.swift。

/// 只负责请求图书详情，避免把网络逻辑放进 SwiftUI View。
final class LibraryCategoryDetailAPI
{

    func fetchDetail(rd: String, no: String) async throws -> LibraryCategoryDetail
    {
        guard let url = URL(string: ShishanyouniAPI.bookDetailURL)
        else
        {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(BookDetailRequest(rd: rd, no: no))

        let (data, response) = try await NetworkService.perform(request: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode)
        else
        {
            throw LibraryCatalogError.invalidResponse
        }

        let apiResponse = try JSONDecoder().decode(BookDetailResponse.self, from: data)

        guard (apiResponse.code == 2 || apiResponse.code == 200),
              let detail = apiResponse.data
        else
        {
            throw LibraryCatalogError.server(message: apiResponse.msg)
        }

        return detail
    }
}
