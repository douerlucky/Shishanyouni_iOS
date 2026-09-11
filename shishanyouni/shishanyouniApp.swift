//
//  shishanyouniApp.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/4.
//

import BackgroundTasks
import SwiftUI
import UserNotifications

@main
struct shishanyouniApp: App
{
    @StateObject private var userinfo = userInfo()
    @StateObject private var iapStore = IAPStore.shared
    @Environment(\.scenePhase) private var scenePhase

    init()
    {
        PreferenceDefaults.register()
        PreferenceDefaults.applyDefaultEnabledMigrationIfNeeded()

        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1"
        else
        {
            return
        }

        requestNotificationPermission()
        ElectricityBGTaskManager.shared.register()
    }

    private func requestNotificationPermission()
    {
        UNUserNotificationCenter.current().delegate = CurriculumNotificationManager.shared
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        { granted, _ in
            print(granted ? "✅ 通知权限已授权" : "⚠️ 通知权限被拒绝")
        }
    }

    var body: some Scene
    {
        WindowGroup
        {
            MainTabView()
                .environmentObject(userinfo)
                .environmentObject(iapStore)
                // 首次安装前没有历史写入时，以及 Widget 被系统延后刷新时，主动补一次。
                .onAppear
                {
                    PersonalScheduleWidgetSync.sync()
                    NextCourseSync.sync()
                }
                .onChange(of: scenePhase)
                { newPhase in
                    guard newPhase == .active else { return }
                    PersonalScheduleWidgetSync.sync()
                    NextCourseSync.sync()
                }
        }
    }
}

// 默认配色集
struct DefaultAppColor
{
    static let orangeRed = Color.adaptive(light: Color(red: 255 / 255, green: 117 / 255, blue: 0 / 255), dark: Color(red: 1.0, green: 0.55, blue: 0.15))
    static let hotPink = Color.adaptive(light: Color(red: 239 / 255, green: 91 / 255, blue: 156 / 255), dark: Color(red: 0.96, green: 0.50, blue: 0.70))
    static let coralRed = Color.adaptive(light: Color(red: 241 / 255, green: 91 / 255, blue: 108 / 255), dark: Color(red: 0.96, green: 0.50, blue: 0.55))
    static let orange = Color.adaptive(light: Color(red: 242 / 255, green: 101 / 255, blue: 34 / 255), dark: Color(red: 0.97, green: 0.55, blue: 0.25))
    static let brown = Color.adaptive(light: Color(red: 165 / 255, green: 103 / 255, blue: 63 / 255), dark: Color(red: 0.72, green: 0.50, blue: 0.35))
    static let purple = Color.adaptive(light: Color(red: 133 / 255, green: 82 / 255, blue: 161 / 255), dark: Color(red: 0.60, green: 0.42, blue: 0.70))
    static let violet = Color.adaptive(light: Color(red: 141 / 255, green: 75 / 255, blue: 187 / 255), dark: Color(red: 0.65, green: 0.42, blue: 0.78))
    static let magenta = Color.adaptive(light: Color(red: 255 / 255, green: 0 / 255, blue: 151 / 255), dark: Color(red: 1.0, green: 0.30, blue: 0.65))
    static let dustyPurple = Color.adaptive(light: Color(red: 114 / 255, green: 94 / 255, blue: 130 / 255), dark: Color(red: 0.55, green: 0.45, blue: 0.60))
    static let limeGreen = Color.adaptive(light: Color(red: 127 / 255, green: 184 / 255, blue: 14 / 255), dark: Color(red: 0.58, green: 0.78, blue: 0.20))
    static let mintGreen = Color.adaptive(light: Color(red: 101 / 255, green: 194 / 255, blue: 148 / 255), dark: Color(red: 0.48, green: 0.80, blue: 0.65))
    static let oliveGreen = Color.adaptive(light: Color(red: 120 / 255, green: 146 / 255, blue: 98 / 255), dark: Color(red: 0.55, green: 0.65, blue: 0.48))
    static let skyBlue = Color.adaptive(light: Color(red: 51 / 255, green: 163 / 255, blue: 220 / 255), dark: Color(red: 0.35, green: 0.72, blue: 0.88))
    static let turquoise = Color.adaptive(light: Color(red: 120 / 255, green: 205 / 255, blue: 209 / 255), dark: Color(red: 0.55, green: 0.82, blue: 0.84))
    static let beige = Color.adaptive(light: Color(red: 209 / 255, green: 186 / 255, blue: 116 / 255), dark: Color(red: 0.84, green: 0.76, blue: 0.55))
}
