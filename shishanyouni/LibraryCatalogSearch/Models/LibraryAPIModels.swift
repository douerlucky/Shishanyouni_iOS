import Foundation

//
//  LibraryAPIModels.swift
//  shishanyouni
//
//  馆藏搜索与图书详情的请求、响应。
//  这里只定义接口的数据格式；请求执行、错误处理和界面状态留在业务模块。
//


// MARK: - 馆藏搜索

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

// MARK: - 图书详情

// Book / LibraryCategoryDetail 是简单接口数据，直接供页面展示，无需再复制一套 DTO。
/// 图书详情接口需要的唯一标识。
struct BookDetailRequest: Encodable
{
    let rd: String
    let no: String
}

struct BookDetailResponse: Decodable
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
