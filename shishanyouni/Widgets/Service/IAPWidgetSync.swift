//
//  IAPWidgetSync.swift
//  shishanyouni
//
//  主 App 到课表 Widget 的订阅状态同步器。
//

import Foundation
import WidgetKit

/// 订阅状态来自主 App 的 StoreKit 流程；Widget 只读取脱离 StoreKit 的轻量快照。
enum IAPWidgetSync
{
    static func saveSubscriptionStatus(isActive: Bool, productID: String?, expiration: TimeInterval?)
    {
        // 保留主 App 的旧键，兼容仍从 standard UserDefaults 读取的业务代码。
        UserDefaults.standard.set(isActive, forKey: WidgetAppGroup.Key.campusPassActive)

        if let productID
        {
            UserDefaults.standard.set(productID, forKey: WidgetAppGroup.Key.campusPassProductID)
        }
        else
        {
            UserDefaults.standard.removeObject(forKey: WidgetAppGroup.Key.campusPassProductID)
        }

        if let expiration
        {
            UserDefaults.standard.set(expiration, forKey: WidgetAppGroup.Key.campusPassExpiration)
        }
        else
        {
            UserDefaults.standard.removeObject(forKey: WidgetAppGroup.Key.campusPassExpiration)
        }

        IAPWidgetShared.saveStatus(
            IAPWidgetSubscriptionStatus(
                isActive: isActive,
                productID: productID,
                expiration: expiration
            )
        )

        // 订阅状态同时决定课表、日程、桌面下节课和锁屏下节课是否可以展示内容。
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetAppGroup.Kind.curriculum)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetAppGroup.Kind.personalSchedule)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetAppGroup.Kind.nextCourse)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetAppGroup.Kind.screenlockNextCourse)
    }

}
