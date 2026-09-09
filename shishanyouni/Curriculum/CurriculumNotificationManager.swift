//
//  CurriculumNotificationManager.swift
//  shishanyouni
//
//  上课提醒推送通知管理器
//

import Foundation
import UserNotifications
import UIKit

class CurriculumNotificationManager: NSObject, UNUserNotificationCenterDelegate {

    static let shared = CurriculumNotificationManager()

    private let reminderEnabledKey = "schedule_reminder_enabled_courses"

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    var reminderMinutesBefore: Int {
        get { UserDefaults.standard.integer(forKey: "scheduleNotificationMinutes").nonZero ?? 10 }
        set { UserDefaults.standard.set(newValue, forKey: "scheduleNotificationMinutes") }
    }

    private var enabledCourseIDs: Set<String> {
        get {
            let arr = UserDefaults.standard.stringArray(forKey: reminderEnabledKey) ?? []
            return Set(arr)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: reminderEnabledKey)
        }
    }

    func isReminderEnabled(for courseID: String) -> Bool {
        enabledCourseIDs.contains(courseID)
    }

    func toggleReminder(for courseID: String, enabled: Bool) {
        if enabled {
            var ids = enabledCourseIDs
            ids.insert(courseID)
            enabledCourseIDs = ids
        } else {
            var ids = enabledCourseIDs
            ids.remove(courseID)
            enabledCourseIDs = ids
        }
        rescheduleAllNotifications()
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error { print("❌ 通知权限请求失败: \(error)") }
            print(granted ? "✅ 通知权限已授权" : "⚠️ 通知权限被拒绝")
        }
    }

    func rescheduleAllNotifications() {
        let enabledIDs = enabledCourseIDs
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        if enabledIDs.isEmpty {
            print("📭 无已开启提醒的课程，已清除所有提醒")
            return
        }
        let courses = CurriculumStore.shared.loadCourses()
        let semesterStart = semesterStartDate()
        var scheduledCount = 0
        for course in courses {
            guard enabledIDs.contains(course.id) else { continue }
            scheduledCount += scheduleReminders(for: course, semesterStart: semesterStart)
        }
        print("🔔 提醒调度完成：为 \(enabledIDs.count) 门课程安排了 \(scheduledCount) 条提醒")
    }

    private func semesterStartDate() -> Date {
        if let date = CurriculumStore.shared.loadSemesterStartDate() {
            return date
        }
        let ts = UserDefaults.standard.double(forKey: "semesterStartDateTimestamp")
        if ts > 0 {
            return Date(timeIntervalSince1970: ts)
        }
        var components = DateComponents()
        components.year = 2026; components.month = 3; components.day = 2
        return Calendar.current.date(from: components) ?? Date()
    }

    private func scheduleReminders(for course: Course, semesterStart: Date) -> Int {
        var cal = Calendar.current
        cal.firstWeekday = 2

        let startComps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: semesterStart)
        guard let firstMonday = cal.date(from: startComps) else { return 0 }

        let classPeriods: [(start: String, end: String)] = [
            ("8:00", "8:45"), ("8:55", "9:40"), ("10:00", "10:45"), ("10:55", "11:40"),
            ("14:30", "15:15"), ("15:25", "16:10"), ("16:30", "17:15"), ("17:25", "18:10"),
            ("19:00", "19:45"), ("19:50", "20:35"), ("20:40", "21:25"), ("21:30", "22:15"),
        ]

        guard course.start > 0 && course.start <= classPeriods.count else { return 0 }
        let period = classPeriods[course.start - 1]
        var count = 0

        for week in course.weekList {
            guard week >= 1 else { continue }
            let offsetDays = (week - 1) * 7 + (course.day - 1)
            guard let classDate = cal.date(byAdding: .day, value: offsetDays, to: firstMonday) else { continue }

            if classDate < Date() { continue }

            guard let notifyDate = notificationDate(for: classDate, timeString: period.start) else { continue }

            let content = UNMutableNotificationContent()
            content.title = "📚 上课提醒"
            content.body = "\(course.name) 即将开始"
            if let room = course.room { content.body += "\n教室：\(room)" }
            content.sound = .default
            content.badge = nil
            content.interruptionLevel = .timeSensitive

            let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notifyDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

            let identifier = "class_\(course.id)_w\(week)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ 添加通知失败 [\(course.name) 第\(week)周]: \(error)")
                }
            }
            count += 1
        }
        return count
    }

    private func notificationDate(for date: Date, timeString: String) -> Date? {
        let parts = timeString.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return nil }

        let calendar = Calendar.current
        var comps = calendar.dateComponents([.year, .month, .day], from: date)
        comps.hour = hour
        comps.minute = minute
        guard let classTime = calendar.date(from: comps) else { return nil }

        return calendar.date(byAdding: .minute, value: -reminderMinutesBefore, to: classTime)
    }

    func pendingNotificationCount(completion: @escaping (Int) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                let count = requests.filter { $0.identifier.hasPrefix("class_") }.count
                completion(count)
            }
        }
    }

    func cancelAllClassReminders() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests.filter { $0.identifier.hasPrefix("class_") }.map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
