//
//  IAPWidgetShared.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/9/11.
//

import Foundation

/// Widget 需要知道的订阅快照，而不是完整的 StoreKit 交易对象。
struct IAPWidgetSubscriptionStatus: Equatable
{
    let isActive: Bool
    let productID: String?
    let expiration: TimeInterval?
}

/// 订阅状态在 App Group 中的读写。
/// App 侧仍会同时维护旧的 standard UserDefaults，保证已有安装的兼容性。
enum IAPWidgetShared
{
    static func saveStatus(_ status: IAPWidgetSubscriptionStatus)
    {
        guard let defaults = WidgetAppGroup.defaults else { return }

        defaults.set(status.isActive, forKey: WidgetAppGroup.Key.campusPassActive)

        if let productID = status.productID
        {
            defaults.set(productID, forKey: WidgetAppGroup.Key.campusPassProductID)
        }
        else
        {
            defaults.removeObject(forKey: WidgetAppGroup.Key.campusPassProductID)
        }

        if let expiration = status.expiration
        {
            defaults.set(expiration, forKey: WidgetAppGroup.Key.campusPassExpiration)
        }
        else
        {
            defaults.removeObject(forKey: WidgetAppGroup.Key.campusPassExpiration)
        }
    }

    /// 读取当前时刻有效的订阅状态。
    ///
    /// 到期时间一旦过去，即使 App 还没有来得及重新同步 StoreKit，
    /// Widget 也不能继续把过期订阅当成有效。
    static func loadStatus(at date: Date = .now) -> IAPWidgetSubscriptionStatus
    {
        let defaults = WidgetAppGroup.defaults
        let expiration = defaults?.object(forKey: WidgetAppGroup.Key.campusPassExpiration) as? TimeInterval
        let hasNotExpired = expiration.map { $0 > date.timeIntervalSince1970 } ?? true

        return IAPWidgetSubscriptionStatus(
            isActive: (defaults?.bool(forKey: WidgetAppGroup.Key.campusPassActive) ?? false) && hasNotExpired,
            productID: defaults?.string(forKey: WidgetAppGroup.Key.campusPassProductID),
            expiration: expiration
        )
    }

    /// 有限期订阅下一次可能失效的时刻；Widget 用它安排一次重新读取。
    static func nextExpirationDate(after date: Date = .now) -> Date?
    {
        let status = loadStatus(at: date)
        guard status.isActive,
              let expiration = status.expiration,
              expiration > date.timeIntervalSince1970
        else
        {
            return nil
        }
        return Date(timeIntervalSince1970: expiration)
    }
}
