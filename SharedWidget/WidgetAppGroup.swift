//
//  WidgetAppGroup.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/9/11.
//

import Foundation

/// App 与 Widget Extension 共用的存储地址和稳定标识。
///
/// 这里只允许放 Foundation 能理解的值类型、键名和 App Group 信息。
/// 不要把 `Event`、`Course`、SwiftUI View 或 WidgetKit 刷新逻辑放进来：
/// 它们分别属于 App 的业务层和各自的展示层。
enum WidgetAppGroup
{
    /// App 与 Widget 必须使用相同的 App Group，才能访问同一份 UserDefaults。
    static let identifier = "group.cn.edu.hzau.shishanyouni"

    /// 每次访问时再取，避免把可选的 App Group 容器缓存成错误状态。
    static var defaults: UserDefaults?
    {
        UserDefaults(suiteName: identifier)
    }

    /// 继续沿用已有键名，迁移后老用户的本地课表、背景和订阅信息仍可读取。
    enum Key
    {
        /// `[WidgetCourse]` 的 JSON Data；主 App 写入，课表 Widget 读取。
        static let savedCourses = "saved_courses"

        /// 学期第一天的 Unix 时间戳；用于计算当前教学周。
        static let semesterStartTimestamp = "semesterStartDateTimestamp"

        /// App 当前选择的教学周；课表 Widget 在无法现场计算时使用。
        static let currentWeek = "schedule_current_week"

        /// App Group 容器里背景图片文件的文件名。
        static let backgroundImageFilename = "scheduleBackgroundImageFilename"

        /// 课表背景图的不透明度。
        static let backgroundOpacity = "scheduleBackgroundOpacity"

        /// 校园通行证订阅是否有效。
        static let campusPassActive = "iap_campus_pass_active"

        /// 当前生效的校园通行证商品 ID。
        static let campusPassProductID = "iap_campus_pass_product_id"

        /// 校园通行证订阅到期时间的时间戳。
        static let campusPassExpiration = "iap_campus_pass_expiration"

        /// 日程 Widget 的展示事项列表。
        /// 类型：`[WidgetScheduleItem]` 的 JSON Data。
        /// 写入：主 App 的 `PersonalScheduleWidgetSync`。
        /// 读取：日程 Widget 的 TimelineProvider。
        static let personalScheduleItems = "widget.personal_schedule.items"

        /// 下节课 Widget 的候选课程列表。
        /// 类型：`[WidgetNextCourse]` 的 JSON Data。
        /// 写入：主 App 的 `NextCourseSync`；读取：下节课 Widget 的 TimelineProvider。
        static let nextCourseItems = "widget.next_course.items"
    }

    /// WidgetKit 用这些固定字符串定位具体小组件，Widget 标识。
    enum Kind
    {
        static let curriculum = "ScheduleWidget"
        static let personalSchedule = "PersonalScheduleWidget"
        /// 桌面小型“下节课”组件；保持原 kind，已添加到主屏的旧组件不会失效。
        static let nextCourse = "NextCourseWidget"
        /// 锁屏矩形“下节课”组件；独立 kind 让它拥有独立的布局和 WidgetKit 时间线。
        static let screenlockNextCourse = "ScreenlockNextCourseWidget"
    }
}
