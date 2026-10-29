import Combine
import SwiftUI

// 首页功能入口的数据流：
// HomeView.allFeatures（所有可用功能）
//   -> HomeLayer.preferredKeys（用户选择/排序，持久化）
//   -> HomeView.featuredFeatures（当前首页可见项）
//   -> HomeFeatureGridView（首页与全部功能共用的可编辑三列 Grid）

/// 用于保存首页入口偏好和连接路由的稳定 ID。
/// rawValue 已写入 UserDefaults，改名会让旧用户的首页配置失效。
enum HomeFeatureKey: String, CaseIterable, Codable, Identifiable
{
    case grades
    case exams
    case allCourses
    case chooseCourse
    case classroom
    case nanhuRun
    case physicalTest
    case physicalCalculator
    case itc
    case library
    case libraryCatalog
    case electricity
    case bus
    case strategy
    case club
    case aiAssistant
    case debug

    var id: String { rawValue }
}

/// 一个实际可展示、可点击的首页入口。
/// `action` 由 HomeView 创建，通常只是切换对应的导航状态。
struct HomeFeatureItem: Identifiable
{
    let key: HomeFeatureKey
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var id: HomeFeatureKey { key }
}

/// 管理“主页常用功能”的选择和排序，并将结果保存到 UserDefaults。
/// 它只存 key，不存标题/图标，避免展示配置与业务入口定义分散。
final class HomeLayer: ObservableObject
{
    /// 当前用户选中的功能及顺序；@Published 会驱动首页 Grid 自动更新。
    @Published private(set) var preferredKeys: [HomeFeatureKey]
    /// 全部功能的目录顺序与常用功能独立，按分类筛选后使用。
    @Published private(set) var catalogKeys: [HomeFeatureKey]

    /// 只存用户选择；所有功能详情仍以 HomeView.allFeatures 为唯一来源。
    private static let storageKey = "home_preferred_feature_keys"
    private static let catalogStorageKey = "home_catalog_feature_keys"
    /// 首次安装、尚无本地配置时显示的默认常用功能。
    private static let guestDefaultKeys: [HomeFeatureKey] = [
        .classroom,
        .physicalCalculator,
        .bus,
        .strategy,
        .club
    ]
    /// 学生首次登录后展示的常用入口，按首页从左到右、从上到下的顺序排列。
    private static let firstLoginDefaultKeys: [HomeFeatureKey] = [
        .grades,
        .exams,
        .classroom,
        .nanhuRun,
        .bus,
        .strategy,
        .club
    ]

    private let defaults: UserDefaults
    /// 只要用户调整过首页（包括清空全部入口），就不再用首次登录默认值覆盖。
    private var hasSavedPreference = false

    init(defaults: UserDefaults = .standard)
    {
        self.defaults = defaults
        catalogKeys = defaults.data(forKey: Self.catalogStorageKey)
            .flatMap { try? JSONDecoder().decode([HomeFeatureKey].self, from: $0) } ?? []

        // 优先恢复用户上一次编辑结果；解码失败或首次进入时才使用默认入口。
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([HomeFeatureKey].self, from: data)
        {
            preferredKeys = decoded
            hasSavedPreference = true
        }
        else
        {
            preferredKeys = Self.guestDefaultKeys
        }
    }

    /// 登录成功后，为尚未配置过首页的用户设置登录版默认入口。
    ///
    /// 游客主动增删或排序过入口、以及旧用户已有的持久化配置都会被保留；
    /// 因此这个方法可以在 `onAppear` 和登录状态变化时安全地重复调用。
    func applyFirstLoginDefaultsIfNeeded(for username: String)
    {
        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !hasSavedPreference
        else { return }

        preferredKeys = Self.firstLoginDefaultKeys
        save()
    }

    /// 全部功能页用它判断该入口是否已经在首页，从而决定是否显示加号。
    func contains(_ key: HomeFeatureKey) -> Bool
    {
        preferredKeys.contains(key)
    }

    /// 将入口追加到首页末尾；重复添加会被忽略。
    func add(_ key: HomeFeatureKey)
    {
        guard !preferredKeys.contains(key) else { return }
        preferredKeys.append(key)
        save()
    }

    /// 从首页移除入口，但不会影响“全部功能”目录本身。
    func remove(_ key: HomeFeatureKey)
    {
        preferredKeys.removeAll { $0 == key }
        save()
    }

    /// 按 key 调整顺序的通用接口；当前拖拽 Grid 使用 updateVisibleOrder 批量回传顺序。
    func move(_ sourceKey: HomeFeatureKey, before targetKey: HomeFeatureKey)
    {
        guard sourceKey != targetKey,
              let sourceIndex = preferredKeys.firstIndex(of: sourceKey),
              let targetIndex = preferredKeys.firstIndex(of: targetKey)
        else { return }

        let moved = preferredKeys.remove(at: sourceIndex)
        let adjustedTarget = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
        preferredKeys.insert(moved, at: adjustedTarget)
        save()
    }

    func updateVisibleOrder(_ visibleKeys: [HomeFeatureKey])
    {
        // 游客模式会暂时隐藏部分功能；排序时保留这些不可见 key，登录后仍能恢复。
        let visibleSet = Set(visibleKeys)
        let hiddenKeys = preferredKeys.filter { !visibleSet.contains($0) }
        preferredKeys = visibleKeys + hiddenKeys
        save()
    }

    /// 只返回当前模式可用的入口；例如游客模式会隐藏成绩、考试等登录功能。
    func visiblePreferredKeys(from availableKeys: [HomeFeatureKey]) -> [HomeFeatureKey]
    {
        let allowed = Set(availableKeys)
        return preferredKeys.filter { allowed.contains($0) }
    }

    /// 已保存的目录项按用户顺序排列；新增功能仍按页面默认顺序追加。
    func visibleCatalogKeys(from availableKeys: [HomeFeatureKey]) -> [HomeFeatureKey]
    {
        let allowed = Set(availableKeys)
        let saved = catalogKeys.filter { allowed.contains($0) }
        let savedSet = Set(saved)
        return saved + availableKeys.filter { !savedSet.contains($0) }
    }

    /// 只更新当前分类，其他分类及游客模式下不可见的项目都予以保留。
    func updateCatalogOrder(_ orderedKeys: [HomeFeatureKey])
    {
        let updated = Set(orderedKeys)
        catalogKeys = orderedKeys + catalogKeys.filter { !updated.contains($0) }
        if let data = try? JSONEncoder().encode(catalogKeys)
        {
            defaults.set(data, forKey: Self.catalogStorageKey)
        }
    }

    private func save()
    {
        if let data = try? JSONEncoder().encode(preferredKeys)
        {
            defaults.set(data, forKey: Self.storageKey)
            hasSavedPreference = true
        }
    }
}

