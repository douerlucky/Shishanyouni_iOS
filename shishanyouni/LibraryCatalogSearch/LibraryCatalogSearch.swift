//
//  LibraryCatalogSearch.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/9/27.
//

import Foundation

// 馆藏接口模型位于 API/Models/LibraryAPIModels.swift。

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

class LibraryCatalogSearch
{

    private func makeSearchRequest(
        keyword: String,
        searchType: SearchType,
        page: Int
    ) throws -> URLRequest //一封即将发给服务器的请求
    {
        guard let url = URL(string: ShishanyouniAPI.bookListURL)
        else
        {
            throw URLError(.badURL)
        }

        let body = BookListRequest(
            kw: keyword,
            searchType: searchType,
            page: page
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        return request
    }

    func search(
        keyword: String,
        searchType: SearchType,
        page: Int = 1
    ) async throws -> BookListResult
    {
        let request = try makeSearchRequest(
            keyword: keyword,
            searchType: searchType,
            page: page
        )

        let (data, response) = try await NetworkService.perform(request: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode)
        else
        {
            throw URLError(.badServerResponse)
        }

        let apiResponse = try JSONDecoder().decode(BookListResponse.self, from: data)

        guard (apiResponse.code == 2 || apiResponse.code == 200),
              let result = apiResponse.data
        else
        {
            throw LibraryCatalogError.server(message: apiResponse.msg)
        }

        return result
    }
}
