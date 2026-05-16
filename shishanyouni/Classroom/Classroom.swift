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

// MARK: - 关注教室模型

/// 关注的单个教室（持久化）
struct FavoriteClassroom: Codable, Identifiable, Equatable
{
    let id: UUID
    /// API 查询参数，如 "三教A3"、"一教2"
    let siteName: String
    /// 在该楼层 data 数组中的 0-based 下标，如第1间教室 = 0
    let arrayIndex: Int
    /// UI 显示名称，如 "三教A301"、"一教201"
    let displayName: String
}

// MARK: - 关注教室 Store

class FavoriteClassroomStore: ObservableObject
{
    @Published var favorites: [FavoriteClassroom] = []

    /// key: "\(siteName)_\(arrayIndex)"，value: 长度为5的slots数组
    @Published var slotsMap: [String: [Int]] = [:]

    @Published var isFetchingFavorites = false

    private let storageKey = "favoriteClassrooms_v2"

    init() { load() }

    // MARK: 持久化

    private func load()
    {
        guard let raw = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([FavoriteClassroom].self, from: raw)
        else { return }
        favorites = decoded
    }

    private func save()
    {
        if let encoded = try? JSONEncoder().encode(favorites)
        {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    // MARK: 增删查

    func slotKey(_ fav: FavoriteClassroom) -> String
    {
        "\(fav.siteName)_\(fav.arrayIndex)"
    }

    func isFavorited(siteName: String, arrayIndex: Int) -> Bool
    {
        favorites.contains { $0.siteName == siteName && $0.arrayIndex == arrayIndex }
    }

    func add(siteName: String, arrayIndex: Int, displayName: String)
    {
        guard !isFavorited(siteName: siteName, arrayIndex: arrayIndex) else { return }
        favorites.append(FavoriteClassroom(
            id: UUID(),
            siteName: siteName,
            arrayIndex: arrayIndex,
            displayName: displayName
        ))
        save()
    }

    func remove(siteName: String, arrayIndex: Int)
    {
        favorites.removeAll { $0.siteName == siteName && $0.arrayIndex == arrayIndex }
        slotsMap.removeValue(forKey: "\(siteName)_\(arrayIndex)")
        save()
    }

    // MARK: 拉取指定日期数据

    /// 为每条关注记录查询指定日期的占用情况。
    /// - Parameters:
    ///   - dateStr: 与主查询保持一致的日期字符串，格式 "yyyy-MM-dd"
    ///   - service: ClassroomService 实例
    func fetchSlots(dateStr: String, service: ClassroomService) async
    {
        guard !favorites.isEmpty else { return }

        await MainActor.run { isFetchingFavorites = true }

        // 按 siteName 去重，同一楼层只发一次网络请求
        let uniqueSiteNames = Array(Set(favorites.map { $0.siteName }))

        // siteName → 该楼层完整 data 二维数组
        var floorDataMap: [String: [[Int]]] = [:]

        await withTaskGroup(of: (String, [[Int]]).self) { group in
            for sn in uniqueSiteNames
            {
                group.addTask
                {
                    let rawData = (try? await service.fetchRawData(dateStr: dateStr, siteName: sn)) ?? []
                    return (sn, rawData)
                }
            }
            for await (sn, rawData) in group
            {
                floorDataMap[sn] = rawData
            }
        }

        // 将每条关注映射到对应的 slots
        var newMap: [String: [Int]] = [:]
        for fav in favorites
        {
            guard let floorData = floorDataMap[fav.siteName],
                  fav.arrayIndex < floorData.count,
                  floorData[fav.arrayIndex].count == 5
            else { continue }

            newMap[slotKey(fav)] = floorData[fav.arrayIndex]
        }

        await MainActor.run
        {
            slotsMap = newMap
            isFetchingFavorites = false
        }
    }
}

// MARK: - 教室网络服务

class ClassroomService
{
    private let baseURL = "https://lion.hzau.edu.cn//app/ios/v2/freeroom/getToday"

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

        let (data, response) = try await URLSession.shared.data(for: request)

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
