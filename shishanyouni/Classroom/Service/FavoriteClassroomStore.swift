// 关注教室的唯一存储入口。

import Foundation
import SwiftUI

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
    ///   - service: ClassroomAPI 实例
    func fetchSlots(dateStr: String, service: ClassroomAPI) async
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

        let updatedSlots = newMap
        await MainActor.run
        {
            slotsMap = updatedSlots
            isFetchingFavorites = false
        }
    }
}
