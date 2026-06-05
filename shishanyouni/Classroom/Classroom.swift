//
//  Classroom.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/3/21.
//


import Foundation

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

// MARK: - 渲染模型

struct RoomStatus: Identifiable
{
    let id = UUID()
    /// 0-based 数组下标（与 API 返回的 data 数组对应）
    let arrayIndex: Int
    let slots: [Int]        // 长度为5：1-2节, 3-4节, 5-6节, 7-8节, 9-12节 (0空闲/1占用)
}

// MARK: - 关注教室模型（数据结构已迁移至 Data/UserData.swift）
// MARK: - 教室网络服务

class ClassroomService
{
    private let baseURL = "https://lion.hzau.edu.cn/app/ios/freeroom/getToday"

    /// 获取空教室数据，转换为 RoomStatus（arrayIndex 为 0-based）
    func fetchEmptyRooms(dateStr: String, siteName: String) async throws -> [RoomStatus]
    {
        let rawData = try await fetchRawData(dateStr: dateStr, siteName: siteName)
        return rawData.enumerated().compactMap { index, slots in
            slots.count == 5 ? RoomStatus(arrayIndex: index, slots: slots) : nil
        }
    }

    /// 获取原始 data 二维数组（供 FavoriteClassroomStore 直接按下标取值用）
    func fetchRawData(dateStr: String, siteName: String) async throws -> [[Int]]
    {
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "dateStr",  value: dateStr),
            URLQueryItem(name: "siteName", value: siteName)
        ]

        guard let url = components.url else
        {
            throw NSError(domain: "ClassroomService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "URL构建失败，检查参数是否合法"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await NetworkService.perform(request: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else
        {
            throw NSError(domain: "ClassroomService", code: 500,
                          userInfo: [NSLocalizedDescriptionKey: "网络请求失败"])
        }

        let decoded = try JSONDecoder().decode(ClassroomResponse.self, from: data)

        guard decoded.success == true || decoded.code == 200 || decoded.code == 2 else
        {
            let msg = decoded.msg ?? "服务器返回未知错误"
            throw NSError(domain: "ClassroomService", code: decoded.code ?? -1,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }

        return decoded.data ?? []
    }
}
