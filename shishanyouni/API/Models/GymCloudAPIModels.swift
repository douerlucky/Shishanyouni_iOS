//
//  GymCloudAPIModels.swift
//  shishanyouni
//
//  狮山有你南湖跑接口的响应。
//  这里只定义接口的数据格式；请求执行、错误处理和界面状态留在业务模块。
//

import Foundation

// RunScore 和 PhysicalScore 是业务 / 缓存模型，仍保留在 GymCloud 模块。
struct LionSouthlakeResponse: Decodable
{
    let msg: String?
    let code: Int
    let data: LionSouthlakeData?
    let success: Bool?

    var isSuccess: Bool
    {
        success == true || code == 2 || code == 200
    }
}

struct LionSouthlakeData: Decodable
{
    let items: [LionSouthlakeItem]?
}

struct LionSouthlakeItem: Decodable
{
    let term: String
    let num: String
}
