//
//  GradeAPIModels.swift
//  shishanyouni
//
//  教务系统与狮山有你成绩接口的响应。
//  这里只定义接口的数据格式；请求执行、错误处理和界面状态留在业务模块。
//

import Foundation

// Grade 仍在成绩模块：它还承担本地缓存、来源记录和成绩明细上下文。
struct TeachingSystemGradeResponse: Decodable
{
    let items: [Grade]
}

struct LionGradeResponse: Decodable
{
    let msg: String?
    let code: Int?
    let data: [Grade]?
    let timestamp: Int64?
    let success: Bool?
    let fail: Bool?
}
