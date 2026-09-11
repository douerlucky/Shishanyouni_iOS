//
//  UserData.swift
//  shishanyouni
//
//  持久化存储数据结构集中管理。
//  所有保存到 UserDefaults / App Group / Keychain 的数据模型与 Store 统一定义在此。
//
//  模块：
//    1. 账号 - userInfo
//    2. 课表 - Course + 扩展 + CurriculumError
//    3. 学业缓存 - CurriculumStore / ExamStore / GradeStore
//    4. 日程 - Event + 关联 enum/struct + EventStore
//    5. 校历 - SchoolCalendarEvent + SchoolEventType + SchoolCalendarStore
//    6. 关注教室 - FavoriteClassroom + FavoriteClassroomStore
//
//  纯网络请求类（*Service / *Query / *Fetcher）保留在原模块文件中。
//

import Foundation
import SwiftUI

private struct QueryCacheEnvelope<T: Codable>: Codable
{
    let items: [T]
    let updatedAt: Date
}

// MARK: - ==================== 1. 账号 Account ====================
/// 用于：LoginView、ProfileView、HomeView

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
    @Published var showNextEvent: Bool = true { didSet { UserDefaults.standard.set(showNextEvent, forKey: "pref_showNextEvent") } }
    @Published var defaultTab: Int = 1 { didSet { UserDefaults.standard.set(defaultTab, forKey: "pref_defaultTab") } }
    @Published var selectedTab: Int = 1

    private var isRunningInPreview: Bool { ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" }

    init()
    {
        PreferenceDefaults.register()
        PreferenceDefaults.applyDefaultEnabledMigrationIfNeeded()
        loadUserInfo()
        showClock = UserDefaults.standard.object(forKey: PreferenceKey.prefShowClock) as? Bool ?? true
        showEnrollmentDays = UserDefaults.standard.object(forKey: PreferenceKey.prefShowEnrollmentDays) as? Bool ?? true
        showNextEvent = UserDefaults.standard.object(forKey: PreferenceKey.prefShowNextEvent) as? Bool ?? true
        defaultTab = UserDefaults.standard.object(forKey: PreferenceKey.prefDefaultTab) as? Int ?? 1
        selectedTab = defaultTab
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


// MARK: 课表 API 解析模型（服务端 JSON 结构）

/// 服务端课表单条记录
/// 用于：CurriculumService 解析 API 响应 → 转为 Course
struct TimetableModel: Decodable
{
    let name: String
    let room: String?
    let teacher: String?
    let weekList: [Int]
    let start: Int
    let step: Int
    let day: Int
    let term: String?
    let colorRandom: Int
    let weeks: String?
    let time: String?
    /// 教务课表接口可能直接返回的考核方式（考试/考查/未安排）。
    /// 狮山有你接口没有返回时，会在导入流程中通过教务课表接口补齐。
    let assessmentMethod: String?

    private enum CodingKeys: String, CodingKey {
        case name, room, teacher, weekList, weeks, week
        case start, period, step, length, day, term, colorRandom, time, khfsmc
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        room = try c.decodeIfPresent(String.self, forKey: .room)
        teacher = try c.decodeIfPresent(String.self, forKey: .teacher)
        weekList = try c.decodeIfPresent([Int].self, forKey: .weekList) ?? []
        start = try c.decodeIfPresent(Int.self, forKey: .start)
            ?? c.decodeIfPresent(Int.self, forKey: .period) ?? 1
        step = try c.decodeIfPresent(Int.self, forKey: .step)
            ?? c.decodeIfPresent(Int.self, forKey: .length) ?? 1
        day = try c.decode(Int.self, forKey: .day)
        term = try c.decodeIfPresent(String.self, forKey: .term)
        colorRandom = try c.decodeIfPresent(Int.self, forKey: .colorRandom) ?? abs(name.hashValue % 32)
        weeks = try c.decodeIfPresent(String.self, forKey: .week)
        time = try c.decodeIfPresent(String.self, forKey: .time)
        assessmentMethod = try c.decodeIfPresent(String.self, forKey: .khfsmc)
    }
}

/// 课表 API 返回的数据体
struct TimetableData: Decodable
{
    let timetableModels: [TimetableModel]
    let others: [String]?
    let startDate: String?
    let loadTime: Int64?

    private enum CodingKeys: String, CodingKey { case timetableModels, timeTable, others, startDate, loadTime }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        timetableModels = try c.decodeIfPresent([TimetableModel].self, forKey: .timetableModels)
            ?? c.decodeIfPresent([TimetableModel].self, forKey: .timeTable) ?? []
        others = try c.decodeIfPresent([String].self, forKey: .others)
        startDate = try c.decodeIfPresent(String.self, forKey: .startDate)
        loadTime = try c.decodeIfPresent(Int64.self, forKey: .loadTime)
    }
}

/// 课表 API 顶层响应
struct TimetableResponse: Decodable
{
    let msg: String?
    let code: Int
    let data: TimetableData?
    var isSuccess: Bool { code == 200 || code == 2 }
}


/// 用于：CurriculumView、AllCurriculumSetting、CurriculumWidgetSync、ManualCourseEditorView

struct Course: Identifiable, Codable
{
    let id: String // 唯一标识服务端课程 = "term_day_start_name"，手动课程 = "manual_UUID"
    let name: String // 课程名称
    let day: Int // 周几（1=周一 … 7=周日）
    let start: Int // 开始节次
    let step: Int // 连续上课节数
    let room: String? // 教室
    let teacher: String? // 教师
    let weekList: [Int] // 上课的具体周次列表，如 [1,2,3,4,5,6,7,8,9,12]
    let weeks: String? // 上课周次文本描述，如 "1-9周,12周"（仅用于显示，逻辑判断用 weekList）
    let term: String? // 学期标识，如 "2025-2"
    var colorRandom: Int // 颜色索引（来自服务端 colorRandom，手动课程随机分配）
    var customColorHex: String? // 用户自定义颜色（十六进制，如 "#FF6B6B"），nil = 使用 colorRandom
    var isManual: Bool // true = 用户手动添加，false = 服务端导入
    /// 考核方式：考试、考查；未安排或尚未同步时为 nil。
    /// 使用可选值兼容旧版本已经保存的课表数据。
    var assessmentMethod: String? = nil

    var endPeriod: Int { start + step - 1 } // 计算结束节次
    var parsedWeeks: Set<Int> { Set(weekList) } // 本课程上课的周次集合（供 CurriculumView 过滤使用）
}

extension Course
{
    init(from model: TimetableModel)
    {
        // ID 包含 step 和 weekList 指纹，确保同一课程不同时间配置不会 ID 冲突
        let sortedWL = model.weekList.sorted()
        let weekTag = sortedWL.isEmpty ? "none" : "\(sortedWL.first!)-\(sortedWL.last!)x\(sortedWL.count)"
        let uniqueID = "\(model.term ?? "unknown")_day\(model.day)_s\(model.start)_n\(model.step)_w\(weekTag)_\(model.name)"

        // 周次文本：优先用 weeks，其次 time，最后从 weekList 拼回
        let weeksText: String? = {
            if let w = model.weeks, !w.isEmpty { return w }
            if let t = model.time, !t.isEmpty { return t }
            if model.weekList.isEmpty { return nil }
            return model.weekList.sorted().map { "\($0)" }.joined(separator: ",") + "周"
        }()

        self.init(
            id: uniqueID,
            name: model.name,
            day: model.day,
            start: model.start,
            step: model.step,
            room: model.room.flatMap { $0.isEmpty ? nil : $0 },
            teacher: model.teacher.flatMap { $0.isEmpty ? nil : $0 },
            weekList: model.weekList,
            weeks: weeksText,
            term: model.term,
            colorRandom: model.colorRandom,
            customColorHex: nil,
            isManual: false,
            assessmentMethod: model.assessmentMethod
        )
    }
}

// MARK: - 手动课程工厂

extension Course
{
    static func createManualCourse(
        name: String,
        weekday: Int,
        startPeriod: Int,
        endPeriod: Int,
        weeks: Set<Int>,
        location: String? = nil,
        teacher: String? = nil,
        customColorHex: String? = nil
    ) -> Course
    {
        let uid = "manual_\(UUID().uuidString)"
        let sortedWeeks = weeks.sorted()
        let weeksText = sortedWeeks.map { "\($0)" }.joined(separator: ",") + "周"

        return Course(
            id: uid,
            name: name,
            day: weekday,
            start: startPeriod,
            step: endPeriod - startPeriod + 1,
            room: location,
            teacher: teacher,
            weekList: sortedWeeks,
            weeks: weeksText,
            term: nil,
            colorRandom: Int.random(in: 0 ... 31),
            customColorHex: customColorHex,
            isManual: true
        )
    }
}

enum CurriculumError: LocalizedError
{
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case jsonDecodingFailed(Error)

    var errorDescription: String?
    {
        switch self
        {
        case .invalidURL: return "接口地址无效"
        case .invalidResponse: return "无效的服务器响应"
        case let .httpError(code): return "HTTP 错误：\(code)"
        case let .apiError(msg): return "服务端错误：\(msg)"
        case let .jsonDecodingFailed(err): return "数据解析失败：\(err.localizedDescription)"
        }
    }
}

// MARK: - ==================== 3. 学业缓存 Academic Cache ====================
/// 用于：CurriculumView、ExamView、GradeView、HomeView

class CurriculumStore
{
    static let shared = CurriculumStore()

    private let lastUpdatedKey = "curriculum_last_updated"

    private init() {}

    func saveCourses(_ courses: [Course], semesterStart: Date?)
    {
        CurriculumWidgetSync.saveCourses(courses)
        if let semesterStart
        {
            CurriculumWidgetSync.saveSemesterStartTimestamp(semesterStart.timeIntervalSince1970)
        }
        NextCourseSync.sync(
            courses: courses,
            semesterStart: semesterStart ?? loadSemesterStartDate()
        )
        UserDefaults.standard.set(Date(), forKey: lastUpdatedKey)
        NotificationCenter.default.post(name: .homeNextEventsDidChange, object: nil)
    }

    func loadCourses() -> [Course]
    {
        CurriculumWidgetSync.loadCourses()
    }

    func loadSemesterStartDate() -> Date?
    {
        guard let timestamp = CurriculumWidgetSync.loadSemesterStartTimestamp(), timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    func saveSemesterStartTimestamp(_ timestamp: Double)
    {
        CurriculumWidgetSync.saveSemesterStartTimestamp(timestamp)
        NextCourseSync.sync()
        UserDefaults.standard.set(Date(), forKey: lastUpdatedKey)
        NotificationCenter.default.post(name: .homeNextEventsDidChange, object: nil)
    }

    func lastUpdatedAt() -> Date?
    {
        UserDefaults.standard.object(forKey: lastUpdatedKey) as? Date
    }
}

class ExamStore
{
    static let shared = ExamStore()

    private let latestKey = "exam_cache_latest_v1"

    private init() {}

    private func cacheKey(username: String, year: String, term: String, source: ExamQuerySource) -> String
    {
        "exam_cache_\(username)_\(year)_\(term)_\(source.rawValue)"
    }

    func saveExams(_ exams: [Exam], username: String, year: String, term: String, source: ExamQuerySource)
    {
        let envelope = QueryCacheEnvelope(items: exams, updatedAt: Date())
        guard let data = try? JSONEncoder().encode(envelope) else { return }

        UserDefaults.standard.set(data, forKey: cacheKey(username: username, year: year, term: term, source: source))
        UserDefaults.standard.set(data, forKey: latestKey)
        NotificationCenter.default.post(name: .homeNextEventsDidChange, object: nil)
    }

    func loadExams(username: String, year: String, term: String, source: ExamQuerySource) -> [Exam]
    {
        guard let data = UserDefaults.standard.data(forKey: cacheKey(username: username, year: year, term: term, source: source)),
              let envelope = try? JSONDecoder().decode(QueryCacheEnvelope<Exam>.self, from: data) else { return [] }
        return envelope.items
    }

    func lastUpdatedAt(username: String, year: String, term: String, source: ExamQuerySource) -> Date?
    {
        guard let data = UserDefaults.standard.data(forKey: cacheKey(username: username, year: year, term: term, source: source)),
              let envelope = try? JSONDecoder().decode(QueryCacheEnvelope<Exam>.self, from: data) else { return nil }
        return envelope.updatedAt
    }

    func loadLatestExams() -> [Exam]
    {
        guard let data = UserDefaults.standard.data(forKey: latestKey),
              let envelope = try? JSONDecoder().decode(QueryCacheEnvelope<Exam>.self, from: data) else { return [] }
        return envelope.items
    }
}

class GradeStore
{
    static let shared = GradeStore()

    private init() {}

    private func cacheKey(username: String, year: String, term: String) -> String
    {
        "grade_cache_\(username)_\(year)_\(term)"
    }

    func saveGrades(_ grades: [Grade], username: String, year: String, term: String)
    {
        let envelope = QueryCacheEnvelope(items: grades, updatedAt: Date())
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey(username: username, year: year, term: term))
    }

    func loadGrades(username: String, year: String, term: String) -> [Grade]
    {
        guard let data = UserDefaults.standard.data(forKey: cacheKey(username: username, year: year, term: term)),
              let envelope = try? JSONDecoder().decode(QueryCacheEnvelope<Grade>.self, from: data) else { return [] }
        return envelope.items
    }

    func lastUpdatedAt(username: String, year: String, term: String) -> Date?
    {
        guard let data = UserDefaults.standard.data(forKey: cacheKey(username: username, year: year, term: term)),
              let envelope = try? JSONDecoder().decode(QueryCacheEnvelope<Grade>.self, from: data) else { return nil }
        return envelope.updatedAt
    }
}


// MARK: - ==================== 4. 日程 Event ====================
/// 用于：PersonalScheduleView、EventEditView

// MARK: - 事项分类
enum EventCategory: String, Codable, CaseIterable, Equatable {
    case trip = "行程"
    case todo = "待办"
    case memo = "备忘"
    
    var systemImage: String {
        switch self {
        case .trip: return "mappin.and.ellipse"
        case .todo: return "checklist"
        case .memo: return "note.text"
        }
    }
    
    var defaultColor: Color {
        switch self {
        case .trip: return Color.adaptive(light: Color(red: 0.20, green: 0.49, blue: 0.92), dark: Color(red: 0.38, green: 0.62, blue: 0.95))
        case .todo: return Color.adaptive(light: Color(red: 0.95, green: 0.47, blue: 0.18), dark: Color(red: 0.98, green: 0.60, blue: 0.35))
        case .memo: return Color.adaptive(light: Color(red: 0.50, green: 0.34, blue: 0.86), dark: Color(red: 0.60, green: 0.48, blue: 0.92))
        }
    }
}

// MARK: - 自定义颜色选项
struct EventColorPalette {
    static let colors: [Color] = [
        Color.adaptive(light: Color(red: 0.20, green: 0.49, blue: 0.92), dark: Color(red: 0.38, green: 0.62, blue: 0.95)),
        Color.adaptive(light: Color(red: 0.95, green: 0.47, blue: 0.18), dark: Color(red: 0.98, green: 0.60, blue: 0.35)),
        Color.adaptive(light: Color(red: 0.50, green: 0.34, blue: 0.86), dark: Color(red: 0.60, green: 0.48, blue: 0.92)),
        Color.adaptive(light: Color(red: 0.26, green: 0.69, blue: 0.31), dark: Color(red: 0.35, green: 0.75, blue: 0.40)),
        Color.adaptive(light: Color(red: 0.89, green: 0.24, blue: 0.22), dark: Color(red: 0.95, green: 0.40, blue: 0.38)),
        Color.adaptive(light: Color(red: 0.12, green: 0.70, blue: 0.74), dark: Color(red: 0.28, green: 0.78, blue: 0.80)),
        Color.adaptive(light: Color(red: 0.90, green: 0.58, blue: 0.16), dark: Color(red: 0.94, green: 0.68, blue: 0.32)),
        Color.adaptive(light: Color(red: 0.69, green: 0.34, blue: 0.78), dark: Color(red: 0.78, green: 0.48, blue: 0.85)),
        Color.adaptive(light: Color(red: 0.70, green: 0.55, blue: 0.40), dark: Color(red: 0.80, green: 0.65, blue: 0.50)),
        Color.adaptive(light: Color(red: 0.45, green: 0.45, blue: 0.55), dark: Color(red: 0.60, green: 0.60, blue: 0.70)),
    ]
    
    static func color(for index: Int) -> Color {
        colors[index % colors.count]
    }
    
    static func hexString(for color: Color) -> String? {
        #if canImport(UIKit)
        let uiColor = UIColor(color)
        guard let components = uiColor.cgColor.components, components.count >= 3 else { return nil }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
        #else
        return nil
        #endif
    }
}

// MARK: - 重复规则
enum RepeatFrequency: String, Codable, CaseIterable, Equatable {
    case daily = "每天"
    case weekly = "每周"
    case biweekly = "隔周"
    case monthly = "每月"
    case custom = "自定义间隔"
}

enum RepeatEndCondition: Codable, Equatable {
    case never
    case untilDate(Date)
    case count(Int)
}

struct RepeatRule: Codable, Equatable {
    let frequency: RepeatFrequency
    let interval: Int  // 间隔，例如 2 表示每2天/周
    let endCondition: RepeatEndCondition
    
    init(frequency: RepeatFrequency, interval: Int = 1, endCondition: RepeatEndCondition = .never) {
        self.frequency = frequency
        self.interval = interval
        self.endCondition = endCondition
    }
}

//用户自己创建的一条日程
struct Event: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String //标题
    var date: Date //日期
    var isAllDay: Bool
    var startTime: Date? //开始时间
    var endTime: Date? //结束时间
    var note: String?
    var location: String? //地点
    var category: EventCategory //分类
    var colorIndex: Int?
    var isCompleted: Bool
    var repeatRule: RepeatRule?

    init(id: UUID = UUID(), title: String, date: Date, isAllDay: Bool = false, startTime: Date? = nil, endTime: Date? = nil, note: String? = nil, location: String? = nil, category: EventCategory = .todo, colorIndex: Int? = nil, isCompleted: Bool = false, repeatRule: RepeatRule? = nil) {
        self.id = id
        self.title = title
        self.date = date
        self.isAllDay = isAllDay
        self.startTime = startTime
        self.endTime = endTime
        self.note = note
        self.location = location
        self.category = category
        self.colorIndex = colorIndex
        self.isCompleted = isCompleted
        self.repeatRule = repeatRule
    }

    var isOverdue: Bool {
        false
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        date = try container.decode(Date.self, forKey: .date)
        isAllDay = try container.decode(Bool.self, forKey: .isAllDay)
        startTime = try container.decodeIfPresent(Date.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        category = try container.decodeIfPresent(EventCategory.self, forKey: .category) ?? .todo
        colorIndex = try container.decodeIfPresent(Int.self, forKey: .colorIndex)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        repeatRule = try container.decodeIfPresent(RepeatRule.self, forKey: .repeatRule)
    }

    var displayColor: Color {
        if let idx = colorIndex {
            return EventColorPalette.color(for: idx)
        }
        return category.defaultColor
    }
}

// MARK: - 数据持久化
//Event 保存和读取日程的仓库
class EventStore {
    private let userDefaultsKey = "saved_events"
    private let completionKey = "event_completions"
    
    static let shared = EventStore()
    
    private init() {}
    
    func saveEvents(_ events: [Event]) {
        do {
            let data = try JSONEncoder().encode(events)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            // Widget 不直接读取 App 的 Event，保存成功后同步一份展示专用 WidgetScheduleItem 列表。
            PersonalScheduleWidgetSync.sync()
            NotificationCenter.default.post(name: .homeNextEventsDidChange, object: nil)
        } catch {
            print("❌ 日程保存失败: \(error)")
        }
    }
    
    func loadEvents() -> [Event] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return []
        }
        do {
            return try JSONDecoder().decode([Event].self, from: data)
        } catch {
            print("❌ 日程加载失败: \(error)")
            return []
        }
    }
    
    // MARK: - 完成状态管理
    func completionKey(for eventId: UUID, date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return "\(eventId.uuidString)_\(dateFormatter.string(from: date))"
    }
    
    func setCompletion(eventId: UUID, date: Date, completed: Bool) {
        var completions = UserDefaults.standard.dictionary(forKey: completionKey) as? [String: Bool] ?? [:]
        completions[completionKey(for: eventId, date: date)] = completed
        UserDefaults.standard.set(completions, forKey: completionKey)
        PersonalScheduleWidgetSync.sync()
        NotificationCenter.default.post(name: .homeNextEventsDidChange, object: nil)
    }
    
    func isCompleted(eventId: UUID, date: Date) -> Bool {
        let completions = UserDefaults.standard.dictionary(forKey: completionKey) as? [String: Bool] ?? [:]
        return completions[completionKey(for: eventId, date: date)] ?? false
    }
    
    func removeCompletions(for eventId: UUID) {
        var completions = UserDefaults.standard.dictionary(forKey: completionKey) as? [String: Bool] ?? [:]
        let keysToRemove = completions.keys.filter { $0.hasPrefix(eventId.uuidString) }
        for key in keysToRemove {
            completions.removeValue(forKey: key)
        }
        UserDefaults.standard.set(completions, forKey: completionKey)
        PersonalScheduleWidgetSync.sync()
        NotificationCenter.default.post(name: .homeNextEventsDidChange, object: nil)
    }
    
    func getAllCompletions() -> [String: Bool] {
        UserDefaults.standard.dictionary(forKey: completionKey) as? [String: Bool] ?? [:]
    }
}


// MARK: - ==================== 4. 校历 SchoolCalendar ====================
/// 用于：SchoolCalendarView、CalendarMonthView

//
//  SchoolCalendarData.swift
//  shishanyouni
//

import Foundation

enum SchoolEventType: String, Codable, CaseIterable {
    case holiday = "假期"
    case exam = "考试"
    case trimesterStart = "学期开始"
    case trimesterEnd = "学期结束"
    case activity = "活动"
    case other = "其他"
    
    var systemImage: String {
        switch self {
        case .holiday: return "sun.max.fill"
        case .exam: return "pencil.and.list.clipboard"
        case .trimesterStart: return "flag.fill"
        case .trimesterEnd: return "flag.checkered"
        case .activity: return "star.fill"
        case .other: return "info.circle.fill"
        }
    }
}

// 校历事件
struct SchoolCalendarEvent: Identifiable, Codable {
    let id: UUID
    var title: String //事件名
    var startDate: Date //开始日期
    var endDate: Date? //结束日期
    var type: SchoolEventType
    var description: String?
    
    init(id: UUID = UUID(), title: String, startDate: Date, endDate: Date? = nil, type: SchoolEventType = .other, description: String? = nil) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.type = type
        self.description = description
    }
    
    func contains(date: Date) -> Bool {
        let cal = Calendar.current
        let target = cal.startOfDay(for: date)
        let start = cal.startOfDay(for: startDate)
        if let end = endDate {
            let endDay = cal.startOfDay(for: end)
            return target >= start && target <= endDay
        }
        return target == start
    }
    
    func formattedDateRange() -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        if let end = endDate {
            if startDate == end {
                fmt.dateFormat = "M月d日"
                return fmt.string(from: startDate)
            }
            fmt.dateFormat = "M月d日"
            let endFmt = DateFormatter()
            endFmt.locale = Locale(identifier: "zh_CN")
            endFmt.dateFormat = "M月d日"
            return "\(fmt.string(from: startDate)) - \(endFmt.string(from: end))"
        }
        fmt.dateFormat = "M月d日"
        return fmt.string(from: startDate)
    }
}

struct SchoolCalendarStore {
    private let userDefaultsKey = "school_calendar_events"
    
    static let shared = SchoolCalendarStore()
    
    private init() {}
    
    func saveEvents(_ events: [SchoolCalendarEvent]) {
        do {
            let data = try JSONEncoder().encode(events)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            // 校历同步完成后，日程 Widget 也要重新挑选下一条安排。
            PersonalScheduleWidgetSync.sync()
            NotificationCenter.default.post(name: .homeNextEventsDidChange, object: nil)
        } catch {
            print("❌ 校历保存失败: \(error)")
        }
    }
    
    func loadEvents() -> [SchoolCalendarEvent] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return buildDefaults()
        }
        do {
            let loaded = try JSONDecoder().decode([SchoolCalendarEvent].self, from: data)
            return loaded.isEmpty ? buildDefaults() : loaded
        } catch {
            print("❌ 校历加载失败: \(error)")
            return buildDefaults()
        }
    }
    
    func semesterStartDate() -> Date {
        let ts = UserDefaults.standard.double(forKey: "semesterStartDateTimestamp")
        if ts > 0 {
            return Date(timeIntervalSince1970: ts)
        }
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 2
        return Calendar.current.date(from: components) ?? Date()
    }
    
    private func lunarHolidayDate(year: Int, holiday: String) -> (month: Int, day: Int)? {
        // 农历节日公历对照表（每年不同）
        let table: [String: [Int: (Int, Int)]] = [
            "dragon": [  // 端午节（农历五月初五）
                2025: (5, 31),
                2026: (6, 19),
                2027: (6, 9),
                2028: (5, 28),
            ],
            "midautumn": [  // 中秋节（农历八月十五）
                2025: (10, 6),
                2026: (9, 25),
                2027: (9, 24),
                2028: (10, 3),
            ],
        ]
        return table[holiday]?[year]
    }
    
    private func buildDefaults() -> [SchoolCalendarEvent] {
        let cal = Calendar.current
        
        var events: [SchoolCalendarEvent] = []
        let semesterStart = semesterStartDate()
        let semYear = cal.component(.year, from: semesterStart)
        let semMonth = cal.component(.month, from: semesterStart)
        
        let isSpring = semMonth <= 6
        
        if isSpring {
            // 春季学期 (2-7月)
            events.append(SchoolCalendarEvent(
                title: "春季学期开学",
                startDate: semesterStart,
                type: .trimesterStart,
                description: "正式上课"
            ))
            
            // 清明节（公历4月4-5日左右，属节气非农历，日期基本固定）
            if let qingming = date(year: semYear, month: 4, day: 4, calendar: cal) {
                events.append(SchoolCalendarEvent(
                    title: "清明节假期",
                    startDate: qingming,
                    endDate: cal.date(byAdding: .day, value: 2, to: qingming),
                    type: .holiday
                ))
            }
            
            if let labor = date(year: semYear, month: 5, day: 1, calendar: cal) {
                events.append(SchoolCalendarEvent(
                    title: "劳动节假期",
                    startDate: labor,
                    endDate: cal.date(byAdding: .day, value: 4, to: labor),
                    type: .holiday
                ))
            }
            
            // 端午节（农历五月初五，公历日期每年查表）
            if let dragonDate = lunarHolidayDate(year: semYear, holiday: "dragon"),
               let dragon = date(year: semYear, month: dragonDate.month, day: dragonDate.day, calendar: cal) {
                events.append(SchoolCalendarEvent(
                    title: "端午节假期",
                    startDate: dragon,
                    endDate: cal.date(byAdding: .day, value: 2, to: dragon),
                    type: .holiday
                ))
            }
            
            let examStart = cal.date(byAdding: .weekOfYear, value: 18, to: semesterStart) ?? semesterStart
            events.append(SchoolCalendarEvent(
                title: "期末考试周",
                startDate: examStart,
                endDate: cal.date(byAdding: .day, value: 11, to: examStart),
                type: .exam
            ))
            
            let semEnd = cal.date(byAdding: .weekOfYear, value: 19, to: semesterStart) ?? semesterStart
            let vacationStart = cal.date(byAdding: .day, value: 1, to: semEnd)
            events.append(SchoolCalendarEvent(
                title: "暑假开始",
                startDate: vacationStart ?? semEnd,
                type: .trimesterEnd,
                description: "正式放暑假"
            ))
        } else {
            // 秋季学期 (9-1月)
            if let fallStart = date(year: semYear, month: 9, day: 1, calendar: cal) {
                events.append(SchoolCalendarEvent(
                    title: "秋季学期开学",
                    startDate: fallStart,
                    type: .trimesterStart,
                    description: "正式上课"
                ))
                
                // 中秋节（农历八月十五，公历日期每年查表）
                if let midDate = lunarHolidayDate(year: semYear, holiday: "midautumn"),
                   let midautumn = date(year: semYear, month: midDate.month, day: midDate.day, calendar: cal) {
                    events.append(SchoolCalendarEvent(
                        title: "中秋节假期",
                        startDate: midautumn,
                        endDate: cal.date(byAdding: .day, value: 2, to: midautumn),
                        type: .holiday
                    ))
                }
                
                if let national = date(year: semYear, month: 10, day: 1, calendar: cal) {
                    events.append(SchoolCalendarEvent(
                        title: "国庆节假期",
                        startDate: national,
                        endDate: cal.date(byAdding: .day, value: 6, to: national),
                        type: .holiday
                    ))
                }
                
                if let newYear = date(year: semYear + 1, month: 1, day: 1, calendar: cal) {
                    events.append(SchoolCalendarEvent(
                        title: "元旦假期",
                        startDate: newYear,
                        endDate: newYear,
                        type: .holiday
                    ))
                }
                
                let examStart = cal.date(byAdding: .weekOfYear, value: 18, to: fallStart) ?? fallStart
                events.append(SchoolCalendarEvent(
                    title: "期末考试周",
                    startDate: examStart,
                    endDate: cal.date(byAdding: .day, value: 6, to: examStart),
                    type: .exam
                ))
                
                let semEnd = cal.date(byAdding: .weekOfYear, value: 19, to: fallStart) ?? fallStart
                let vacationStart = cal.date(byAdding: .day, value: 1, to: semEnd)
                events.append(SchoolCalendarEvent(
                    title: "寒假开始",
                    startDate: vacationStart ?? semEnd,
                    type: .trimesterEnd,
                    description: "正式放寒假"
                ))
            }
        }
        
        return events
    }
    
    private func date(year: Int, month: Int, day: Int, calendar: Calendar) -> Date? {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        return calendar.date(from: comps)
    }
}


// MARK: - ==================== 5. 关注教室 Classroom ====================
/// 用于：ClassroomView

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
