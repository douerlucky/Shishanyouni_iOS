//
//  GuideAPIModels.swift
//  shishanyouni
//
//  攻略列表与攻略详情的接口数据。
//  这里只定义接口的数据格式；请求执行、错误处理和界面状态留在业务模块。
//

import Foundation

// 列表和详情的字段目前相似，但保留独立类型以兼容两个接口各自的变化。
// MARK: - 攻略列表

struct Guide: Codable, Identifiable
{
    let id: Int
    let name: String
    let icon: String?
    let context: String?
    let author: String?
    let time: String?
}

struct GuideResponse: Codable
{
    let msg: String
    let code: Int
    let data: [Guide]?
}

// MARK: - 攻略详情

struct GuideDetail: Codable
{
    let id: Int
    let name: String
    let icon: String?
    let context: String?
    let author: String?
    let time: String?
}

struct GuideDetailResponse: Codable
{
    let msg: String
    let code: Int
    let data: GuideDetail?
}
