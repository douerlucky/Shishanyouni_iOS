//
//  ClubAPIModels.swift
//  shishanyouni
//
//  社团列表与社团详情的接口数据。
//  这里只定义接口的数据格式；请求执行、错误处理和界面状态留在业务模块。
//

import Foundation

// 列表 contact 是单个字符串，详情 contact 是数组，不合并为同一个模型。
// MARK: - 社团列表

struct Club: Identifiable, Decodable
{
    let id: Int
    let name: String
    let avatar: String
    let introduction: String?
    let contact: String?
    let nameIndex: String?
}

struct ClubListResponse: Decodable
{
    let msg: String
    let code: Int
    let data: [[Club]]
    let success: Bool
}

// MARK: - 社团详情

struct ClubDetail: Identifiable, Decodable
{
    let id: Int
    let name: String
    let avatar: String
    let introduction: String?
    let contact: [String]?
    let nameIndex: String?
}

struct ClubDetailResponse: Decodable
{
    let msg: String
    let code: Int
    let data: ClubDetail
    let success: Bool
}
