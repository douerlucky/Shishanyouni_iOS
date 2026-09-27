//
//  LibraryCatalogSearch.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/9/27.
//

import Foundation

enum SearchType: String, Encodable
{
    case anyWord = "wrd"
    case title = "wti"
    case author = "wau"
}

struct BookListRequest: Encodable
{
    let kw: String
    let searchType: SearchType
    let page: Int
}

struct BookListResponse: Decodable
{
    let msg: String // 返回消息
    let code: Int // 错误码
    let data: BookListResult? // 返回的结构体
}

struct BookListResult: Decodable
{
    let bookList: [Book] // 书籍列表(为空则代表没有下一页)
    let page: Int // 页码
    let totalCnt: Int // 总数量
}

struct Book: Decodable, Identifiable
{
    let name: String
    let author: String
    let publish: String
    let rd: String
    let no: String

    var id: String
    {
        "\(rd)-\(no)"
    }
}

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
    private static let listURL = "https://lion.hzau.edu.cn/app/ios/library/bookList"

    private func makeSearchRequest(
        keyword: String,
        searchType: SearchType,
        page: Int
    ) throws -> URLRequest //一封即将发给服务器的请求
    {
        guard let url = URL(string: Self.listURL)
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
