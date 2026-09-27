//
//  LibraryCategoryDetail.swift
//  shishanyouni
//

import Foundation

/// 图书详情接口需要的唯一标识。
private struct BookDetailRequest: Encodable
{
    let rd: String
    let no: String
}

private struct BookDetailResponse: Decodable
{
    let msg: String
    let code: Int
    let data: LibraryCategoryDetail?
}

/// 图书详情页展示的数据。
struct LibraryCategoryDetail: Decodable
{
    let title: String
    let author: String
    let publisher: String
    let isbn: String
    let classification: String
    let siteList: [LibraryBookSite]
}

/// 一条馆藏副本记录。
struct LibraryBookSite: Decodable, Identifiable
{
    let room: String
    let location: String
    let status: String
    let number: String

    var id: String
    {
        "\(room)-\(location)-\(number)"
    }

    /// “不在架上”同样含有“在架”二字，不能只判断是否包含“在架”。
    var isAvailable: Bool
    {
        status.contains("在架") && !status.contains("不在") && !status.contains("借出")
    }
}

/// 只负责请求图书详情，避免把网络逻辑放进 SwiftUI View。
final class LibraryCategoryDetailService
{
    private static let detailURL = "https://lion.hzau.edu.cn/app/ios/library/bookDetail"

    func fetchDetail(rd: String, no: String) async throws -> LibraryCategoryDetail
    {
        guard let url = URL(string: Self.detailURL)
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
