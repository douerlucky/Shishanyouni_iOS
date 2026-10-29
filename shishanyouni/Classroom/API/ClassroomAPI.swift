import Foundation

// MARK: - 关注教室模型（数据结构已迁移至 Classroom/Models/FavoriteClassroom.swift）
// MARK: - 教室网络服务

class ClassroomAPI
{

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
        var components = URLComponents(string: ShishanyouniAPI.classroomURL)!
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
