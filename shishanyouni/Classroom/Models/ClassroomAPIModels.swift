import Foundation

//
//  ClassroomAPIModels.swift
//  shishanyouni
//
//  空教室查询接口的响应；渲染模型 RoomStatus 留在教室模块。
//  这里只定义接口的数据格式；请求执行、错误处理和界面状态留在业务模块。
//


// MARK: - API Response

struct ClassroomResponse: Decodable
{
    let msg: String?
    let code: Int?
    let data: [[Int]]?      // 二维数组：外层是教室列表，内层是5个时间段状态(0空闲/1占用)
    let timestamp: Int64?
    let success: Bool?
    let fail: Bool?
}
