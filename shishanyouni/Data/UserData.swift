//
//  UserData.swift
//  shishanyouni
//
//  所有用户相关数据结构集中管理。
//  打开此文件即可查看 App 中所有数据结构并了解每个模块的数据在哪定义。
//
//  后续若需要复用组件，可根据模块编号在此查找数据结构来源。
//

import Foundation
import SwiftUI

// MARK: - ==================== 1. 账号 Account ====================

/// 全局用户登录状态（唯一在此文件中定义）
/// 属性：username / nickname / plainPassword / encryptedPasswordSchool / encryptedPasswordShishanyouni
///       shishanyouniToken / isCASBound / isShishanyouniBound / showClock / showEnrollmentDays
/// 功能：保存/加载/清除登录凭证、计算入学天数、加密密码
/// 用于：LoginView、ProfileView、HomeView、及所有需要登录态的页面
class userInfo: ObservableObject
{
    private enum StorageKey {
        static let savedUsername = "saved_username"
        static let savedNickname = "saved_nickname"
        static let savedCASBound = "saved_cas_bound"
        static let savedBackendBound = "saved_backend_bound"
        static let savedShishanyouniToken = "saved_shishanyouni_token"
    }

    @Published var username: String = ""
    @Published var nickname: String = ""
    @Published var plainPassword: String = ""
    @Published var encryptedPasswordSchool: String = ""
    @Published var encryptedPasswordShishanyouni: String = ""
    @Published var shishanyouniToken: String = ""
    @Published var isCASBound: Bool = false
    @Published var isShishanyouniBound: Bool = false
    @Published var showClock: Bool = true { didSet { UserDefaults.standard.set(showClock, forKey: "pref_showClock") } }
    @Published var showEnrollmentDays: Bool = true { didSet { UserDefaults.standard.set(showEnrollmentDays, forKey: "pref_showEnrollmentDays") } }

    private var isRunningInPreview: Bool { ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" }

    init()
    {
        loadUserInfo()
        showClock = UserDefaults.standard.bool(forKey: "pref_showClock")
        showEnrollmentDays = UserDefaults.standard.bool(forKey: "pref_showEnrollmentDays")
    }

    var daysSinceEnrollment: Int?
    {
        guard username.count >= 4, let year = Int(username.prefix(4)) else { return nil }
        var components = DateComponents(); components.year = year; components.month = 9; components.day = 1
        guard let enrollmentDate = Calendar.current.date(from: components) else { return nil }
        return (Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: enrollmentDate), to: Calendar.current.startOfDay(for: Date())).day ?? 0) + 1
    }

    func loadUserInfo()
    {
        #if DEBUG
        if let (devUser, devPass) = loadDevConfig(), !devUser.isEmpty {
            username = devUser; plainPassword = devPass; isCASBound = true; isShishanyouniBound = true
            performSchoolEncryption(); performShishanyouniEncryption(); print("✅ 已从 DevConfig.json 自动登录: \(username)"); return
        }
        #endif
        if let savedUsername = UserDefaults.standard.string(forKey: StorageKey.savedUsername), !savedUsername.isEmpty {
            username = savedUsername
            if let savedPassword = KeychainHelper.shared.get(for: savedUsername) {
                if TestAccount.matches(username: savedUsername, password: savedPassword) { TestAccount.apply(to: self) }
                else { plainPassword = savedPassword; performSchoolEncryption(); performShishanyouniEncryption() }
                print("✅ 已自动加载学号: \(username)")
            }
            nickname = UserDefaults.standard.string(forKey: StorageKey.savedNickname) ?? ""
            shishanyouniToken = UserDefaults.standard.string(forKey: StorageKey.savedShishanyouniToken) ?? ""
            if TestAccount.matches(username: username, password: plainPassword) { updateBindingStatus(casBound: true, shishanyouniBound: true) }
            else { isCASBound = UserDefaults.standard.bool(forKey: StorageKey.savedCASBound); isShishanyouniBound = UserDefaults.standard.bool(forKey: StorageKey.savedBackendBound) }
        } else { isCASBound = false; isShishanyouniBound = false }
    }

    func saveUserInfo()
    {
        guard !username.isEmpty, !plainPassword.isEmpty else { return }
        UserDefaults.standard.set(username, forKey: StorageKey.savedUsername)
        KeychainHelper.shared.save(password: plainPassword, for: username)
        UserDefaults.standard.set(nickname, forKey: StorageKey.savedNickname)
        UserDefaults.standard.set(shishanyouniToken, forKey: StorageKey.savedShishanyouniToken)
        persistBindingStatus()
    }

    func clearUserInfo()
    {
        KeychainHelper.shared.delete(for: username)
        for k in [StorageKey.savedUsername, StorageKey.savedNickname, StorageKey.savedCASBound, StorageKey.savedBackendBound, StorageKey.savedShishanyouniToken, "encrypted_password_school"] { UserDefaults.standard.removeObject(forKey: k) }
        username = ""; plainPassword = ""; encryptedPasswordSchool = ""; encryptedPasswordShishanyouni = ""; shishanyouniToken = ""; nickname = ""; isCASBound = false; isShishanyouniBound = false
        print("已清除保存的学号和密码")
    }

    func clearSavedCredentials()
    {
        if !username.isEmpty { KeychainHelper.shared.delete(for: username) }
        for k in [StorageKey.savedUsername, StorageKey.savedNickname, StorageKey.savedCASBound, StorageKey.savedBackendBound, StorageKey.savedShishanyouniToken, "encrypted_password_school"] { UserDefaults.standard.removeObject(forKey: k) }
        print("已清除本地保存的账号信息，保留当前会话")
    }

    func updateBindingStatus(casBound: Bool, shishanyouniBound: Bool) { isCASBound = casBound; isShishanyouniBound = shishanyouniBound }
    func updateShishanyouniToken(_ token: String) { shishanyouniToken = token; UserDefaults.standard.set(token, forKey: StorageKey.savedShishanyouniToken) }
    func performSchoolEncryption() { if let r = encryptSchoolPassword(password: plainPassword) { encryptedPasswordSchool = r; UserDefaults.standard.set(r, forKey: "encrypted_password_school") } }
    func performShishanyouniEncryption() { if let r = encryptShishanyouniPassword(password: plainPassword) { encryptedPasswordShishanyouni = r } }
    func loadUserNickname() { nickname = UserDefaults.standard.string(forKey: StorageKey.savedNickname) ?? "" }
    func saveUserNickname() { UserDefaults.standard.set(nickname, forKey: StorageKey.savedNickname) }
    func debugprint() { print("设定为用户名:\(username)\n原始密码为:\(plainPassword)\n加密的密码为:\(encryptedPasswordSchool)") }
    private func persistBindingStatus() { UserDefaults.standard.set(isCASBound, forKey: StorageKey.savedCASBound); UserDefaults.standard.set(isShishanyouniBound, forKey: StorageKey.savedBackendBound) }

    #if DEBUG
    private func loadDevConfig() -> (String, String)? {
        let configURL = URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("DevConfig.json")
        guard let data = try? Data(contentsOf: configURL), let json = try? JSONSerialization.jsonObject(with: data) as? [String: String], let user = json["username"], let pass = json["password"], !user.isEmpty, !pass.isEmpty else { return nil }
        return (user, pass)
    }
    #endif
}


// MARK: - ==================== 2. 课表 Curriculum ====================

/// 课程数据模型 Course
/// struct Course: Identifiable, Codable（完整定义见 Curriculum/Curriculum.swift）
/// 属性：id / name / day / start / step / room / teacher / weekList / weeks / term / colorRandom / customColorHex / isManual
/// 用于：CurriculumView、AllCurriculumSetting、ManualCourseEditorView、WidgetSharedStore
///
/// 同文件还定义了：
///   TimetableResponse / TimetableData / TimetableModel（服务端 JSON 解析）
///   CurriculumService.fetchCourses（课表拉取服务）
///   CurriculumError / Course.createManualCourse（手动课程工厂）


// MARK: - ==================== 3. 日程 Event ====================

/// 个人日程事项 Event
/// struct Event: Identifiable, Codable, Equatable（完整定义见 Event/Event.swift）
/// 属性：id / title / date / isAllDay / startTime / endTime / note / location / category / colorIndex / isCompleted / repeatRule / priority / dueDate / subtasks
/// 用于：PersonalScheduleView、EventEditView、EventStore
///
/// 同文件还定义了：
///   EventPriority / EventCategory / EventColorPalette / RepeatFrequency / RepeatEndCondition
///   RepeatRule / SubTask / EventStore（日程持久化存储）


// MARK: - ==================== 4. 校历 SchoolCalendar ====================

/// 校历事件 SchoolCalendarEvent
/// struct SchoolCalendarEvent: Identifiable, Codable（完整定义见 SchoolCalendar/SchoolCalendarData.swift）
/// 属性：id / title / startDate / endDate / type / description
/// 用于：SchoolCalendarView、CalendarMonthView
///
/// 同文件还定义了：
///   SchoolEventType / SchoolCalendarStore（校历持久化 + 默认校历生成）


// MARK: - ==================== 5. 考试 Exam ====================

/// 考试 Exam
/// struct Exam: Identifiable, Codable（完整定义见 Exam/Exam.swift）
/// 属性：kcmc / ksmc / kssj / cdmc / zwh / xf / jxbmc / bj / querySource
/// 用于：ExamView、ExamQuery
///
/// 同文件还定义了：
///   ExamQuerySource / ExamQueryError / ExamResponse / ExamQuery（考试查询服务）


// MARK: - ==================== 6. 成绩 Grade ====================

/// 成绩 Grade
/// struct Grade: Identifiable, Codable（完整定义见 Grade/Grade.swift）
/// 属性：kcmc / kcxzmc / xf / cj / jd / khfsmc / ...
/// 用于：GradeView、GPAnalysisView、GradeService
///
/// 同文件还定义了：
///   LionGradeResponse / GradeService（成绩查询服务）


// MARK: - ==================== 7. 空教室 Classroom ====================

/// 教室状态 RoomStatus / FavoriteClassroom
/// struct RoomStatus: Identifiable（完整定义见 Classroom/Classroom.swift）
/// 属性：arrayIndex / slots
/// 用于：ClassroomView（空教室展示）
///
/// struct FavoriteClassroom: Codable, Identifiable, Equatable
/// 属性：id / siteName / arrayIndex / displayName
/// 用于：FavoriteClassroomStore（关注教室持久化）
///
/// 同文件还定义了：
///   ClassroomResponse / ClassroomService / FavoriteClassroomStore


// MARK: - ==================== 8. 电费 Electricity ====================

/// 电费 ElectricityRecord
/// struct ElectricityRecord: Identifiable, Decodable（完整定义见 Electricity/Electricity.swift）
/// 属性：roomId / roomName / balance / baseMeterList / ...
/// 用于：ElectricityView（电费查询）
///
/// 同文件还定义了：
///   ElectricityResponse / ElectricityPageData / MeterDetail / PickerItem
///   BuildingLevelRoomResponse / ElectricityQuery（CAS 电费登录查询服务）


// MARK: - ==================== 9. 体育 GymCloud ====================

/// 环湖跑 RunScore / 体测 PhysicalScore
/// struct RunScore: Identifiable, Codable（完整定义见 GymCloud/GymCloud.swift）
/// 属性：schoolYear / semester / count
/// 用于：NanhuRunView（环湖跑查询）
///
/// struct PhysicalScore: Identifiable, Codable
/// 属性：testYear / totalScore / totalGrade / details / ...
/// 用于：PhysicalTestView（体测查询）
///
/// 同文件还定义了：
///   PhysicalDetail / NanhuRunQuerySource / GymCloudQuery


// MARK: - ==================== 10. 全校课程查询 Course ====================

/// 课程信息 CourseInfo / 教学班 CourseClassInfo
/// struct CourseInfo: Identifiable, Decodable（完整定义见 Course/AllCourse.swift）
/// 用于：AllCourseView（课程搜索）、CourseDetailView（课程详情）
///
/// struct CourseClassInfo: Identifiable, Decodable
/// 用于：CourseDetailView（教学班详情）
///
/// 同文件还定义了：
///   CourseQuerySource / AllCourseResponse / CourseClassResponse / AllCourseQuery


// MARK: - ==================== 11. ITC 平台 ====================

/// ITC 数据结构
/// struct ITC_Course / ITC_Assignment / ITC_Question / ITC_TestData（完整定义见 ITC/ITCFetch.swift）
/// 用于：ITCView、AssignmentDetailView
/// 同文件还定义了：ITCFetch（ITC 登录与抓取服务）


// MARK: - ==================== 12. 图书馆 Library ====================

/// 图书馆座位统计 LibrarySeatStats
/// struct LibrarySeatStats（完整定义见 Library/LibraryService.swift）
/// 属性：available / inUse / notSignedIn
/// 用于：LibraryOverviewView（图书馆座位页面）
/// 同文件还定义了：LibraryService


// MARK: - ==================== 13. 社团 Club ====================

/// 社团 Club
/// struct Club: Identifiable, Decodable（完整定义见 Utils/Club/AllClub.swift）
/// 属性：id / name / avatar / introduction / contact / nameIndex
/// 用于：AllClub（社团列表页面）
/// 同文件还定义了：ClubListResponse


// MARK: - ==================== 14. 攻略 Strategy ====================

/// 攻略 Guide
/// struct Guide: Codable, Identifiable（完整定义见 Utils/Strategy/AllStrategy.swift）
/// 属性：id / name / icon / context / author / time
/// 用于：AllStrategy（攻略列表页面）
/// 同文件还定义了：GuideResponse


// MARK: - ==================== 15. 课程提醒 Notification ====================

/// 课程提醒数据管理在 CurriculumNotificationManager/CurriculumNotificationManager.swift 中
/// 存储结构为 Set<String>（UserDefaults 中存为字符串数组）
/// 提醒 Key 见 UserPreference.swift 中 scheduleReminderEnabledCourses / scheduleNotificationMinutes
