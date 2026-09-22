//
//  UserPreference.swift
//  shishanyouni
//
//  所有用户偏好设置的 Key 集中管理 + 类型安全的读写封装。
//  使用 PreferenceKey 命名空间代替 @AppStorage，统一管理散落的 UserDefaults 键值。
//  避免 @AppStorage / UserDefaults 散落各处，方便统一审计和维护。
//

import Foundation
import WidgetKit

/// App 的整体展示模式。
///
/// “全部”和“无通行证内容”是锁定预设；只有“自定义”允许逐项调整。
enum AppDisplayMode: String, CaseIterable, Identifiable
{
    case all = "all"
    case noCampusPassContent = "noCampusPassContent"
    case custom = "custom"

    var id: String { rawValue }

    var title: String
    {
        switch self
        {
        case .all: return "全部"
        case .noCampusPassContent: return "无通行证内容"
        case .custom: return "自定义"
        }
    }

    var description: String
    {
        switch self
        {
        case .all: return "显示全部页面、首页内容和通行证功能。"
        case .noCampusPassContent: return "关闭日程，保留首页全部内容，并隐藏通行证功能。"
        case .custom: return "按你的偏好调整每项内容。"
        }
    }

    /// 兼容 1.4.x 曾经使用过的存储值，避免升级后模式丢失。
    static func fromStoredValue(_ rawValue: String) -> Self
    {
        switch rawValue
        {
        case "simple": return .noCampusPassContent
        case "complete": return .all
        default: return Self(rawValue: rawValue) ?? .all
        }
    }

}

// MARK: - 所有偏好 Key 常量

/// 所有用户偏好设置 key 集中定义在此处。
/// 使用示例：
///   UserDefaults.standard.set(true, forKey: PreferenceKey.prefShowClock)
enum PreferenceKey
{
    // ========== 账号相关 ==========
    /// 学号 - userInfo / LoginView
    static let savedUsername = "saved_username"
    /// 昵称 - userInfo / ProfileView
    static let savedNickname = "saved_nickname"
    /// CAS 绑定状态 - userInfo / LoginView
    static let savedCASBound = "saved_cas_bound"
    /// 狮山有你后端绑定状态 - userInfo / LoginView
    static let savedBackendBound = "saved_backend_bound"
    /// 狮山有你 Token - userInfo / LoginChecker
    static let savedShishanyouniToken = "saved_shishanyouni_token"
    /// 加密的学校密码 - userInfo.performSchoolEncryption
    static let encryptedPasswordSchool = "encrypted_password_school"
    /// 首页显示时钟 - userInfo → HomeView
    static let prefShowClock = "pref_showClock"
    /// 首页显示入学天数 - userInfo → HomeView
    static let prefShowEnrollmentDays = "pref_showEnrollmentDays"
    /// 首页显示下一个安排 - HomeView
    static let prefShowNextEvent = "pref_showNextEvent"
    /// 默认启动 Tab - MainTabView
    static let prefDefaultTab = "pref_defaultTab"
    /// 功能显示预设 - AppModeSettingView
    static let appDisplayMode = "app_display_mode"
    /// 是否显示“日程与校历”Tab - AppModeSettingView / MainTabView
    static let showScheduleTab = "show_schedule_tab"
    /// 是否显示个人日程；关闭时“日程与校历”Tab 仅显示校历。
    static let showPersonalSchedule = "show_personal_schedule"
    /// 是否显示校园通行证与全部需要通行证的功能入口。
    static let showCampusPassFeatures = "show_campus_pass_features"
    /// 是否显示“我的”页顶部的校园通行证卡片。
    static let showCampusPassCard = "show_campus_pass_card"
    /// 已展示的新功能版本标记 - MainTabView
    static let lastShownWhatsNewVersion = "last_shown_whats_new_version"
    /// 已应用本次默认开启迁移 - App/UserInfo
    static let didApplyDefaultEnabledMigration = "did_apply_default_enabled_migration"
    /// 登录绑定数据源选择 - LoginView
    static let loginBindingSource = "login_binding_source"

    // ========== 课表相关 ==========
    /// 学期开始日期时间戳（Double） - CurriculumView / CurriculumSettingView / Widget
    static let semesterStartDateTimestamp = "semesterStartDateTimestamp"
    /// 课表背景图片文件名 - CurriculumView / CurriculumSettingView / AllCurriculumSetting / Widget
    static let scheduleBackgroundImageFilename = "scheduleBackgroundImageFilename"
    /// 课表显示字体缩放比例 - CurriculumFontSettingView / CurriculumView
    static let curriculumFontScale = "curriculumFontScale"
    /// 课表背景不透明度（0.0 ~ 1.0） - CurriculumView / CurriculumSettingView / AllCurriculumSetting
    static let scheduleBackgroundOpacity = "scheduleBackgroundOpacity"
    /// 课表内容不透明度（0.0 ~ 1.0） - CurriculumView / CurriculumSettingView / AllCurriculumSetting
    static let scheduleContentOpacity = "scheduleContentOpacity"
    /// 液态玻璃效果开关 - CurriculumView / CurriculumSettingView / AllCurriculumSetting
    static let enableLiquidGlassEffect = "enableLiquidGlassEffect"
    /// 首页单独控制背景 - HomeView
    static let homeBackgroundEnabled = "homeBackgroundEnabled"
    /// 日程单独控制背景 - ScheduleView
    static let scheduleBackgroundEnabled = "scheduleBackgroundEnabled"
    /// 课表单独控制背景 - CurriculumView
    static let curriculumBackgroundEnabled = "curriculumBackgroundEnabled"
    /// 上课提前提醒分钟数（Int，默认 10 分钟） - CurriculumSettingView / CurriculumNotificationManager
    static let scheduleNotificationMinutes = "scheduleNotificationMinutes"
    /// 已开启提醒的课程 ID 数组 - CurriculumNotificationManager
    static let scheduleReminderEnabledCourses = "schedule_reminder_enabled_courses"
    /// 课表底部控制条显隐 - CurriculumView
    static let showBottomControls = "showBottomControls"
    /// 当前显示周数 - CurriculumView / Widget
    static let scheduleCurrentWeek = "schedule_current_week"

    // ========== 课表桌面小组件相关（App Group 共享） ==========
    /// 课表课程数据（JSON 编码） - CurriculumWidgetSync / Widget
    static let widgetSavedCourses = "saved_courses"
    /// 校园通行证是否有效（App ↔ Widget 共享） - IAPStore / IAPWidgetSync / Widget
    static let iapCampusPassActive = "iap_campus_pass_active"
    /// 当前生效的订阅商品 ID - IAPStore / IAPWidgetSync
    static let iapCampusPassProductID = "iap_campus_pass_product_id"
    /// 订阅到期时间戳 - IAPStore / IAPWidgetSync
    static let iapCampusPassExpiration = "iap_campus_pass_expiration"

    // ========== 个人日程 Event ==========
    /// 所有日程事项（JSON 编码） - EventStore
    static let savedEvents = "saved_events"
    /// 日程完成状态字典 - EventStore
    static let eventCompletions = "event_completions"

    // ========== 校历 ==========
    /// 校历事件列表（JSON 编码） - SchoolCalendarStore
    static let schoolCalendarEvents = "school_calendar_events"

    // ========== 空教室 ==========
    /// 关注教室列表（JSON 编码） - FavoriteClassroomStore
    static let favoriteClassrooms = "favoriteClassrooms_v2"

    // ========== 考试查询 ==========
    /// 考试查询数据源选择 - ExamView
    static let examQuerySource = "examQuerySource"

    // ========== 缓存（动态 Key 模式） ==========
    /// CAS Cookie 缓存（带命名空间和用户名的动态 key）
    /// 模式：casCookieCache.{namespace}.{username} - CASCookieCache
    static let casCookieCachePrefix = "casCookieCache"
    /// 学术查询结果缓存（带命名空间和用户名的动态 key）
    /// 模式：academicQueryCache.{namespace}.{username}.{parts} - AcademicQueryCache
    static let academicQueryCachePrefix = "academicQueryCache"
}

enum PreferenceDefaults
{
    static func register()
    {
        UserDefaults.standard.register(defaults: [
            PreferenceKey.prefShowClock: true,
            PreferenceKey.prefShowEnrollmentDays: true,
            PreferenceKey.prefShowNextEvent: true,
            PreferenceKey.appDisplayMode: AppDisplayMode.all.rawValue,
            PreferenceKey.showScheduleTab: true,
            PreferenceKey.showPersonalSchedule: true,
            PreferenceKey.showCampusPassFeatures: true,
            PreferenceKey.showCampusPassCard: true,
            PreferenceKey.enableLiquidGlassEffect: true,
        ])
    }

    static func applyDefaultEnabledMigrationIfNeeded()
    {
        guard !UserDefaults.standard.bool(forKey: PreferenceKey.didApplyDefaultEnabledMigration) else { return }

        UserDefaults.standard.set(true, forKey: PreferenceKey.prefShowClock)
        UserDefaults.standard.set(true, forKey: PreferenceKey.prefShowEnrollmentDays)
        UserDefaults.standard.set(true, forKey: PreferenceKey.prefShowNextEvent)
        UserDefaults.standard.set(true, forKey: PreferenceKey.enableLiquidGlassEffect)
        UserDefaults.standard.set(true, forKey: PreferenceKey.didApplyDefaultEnabledMigration)
    }
}
