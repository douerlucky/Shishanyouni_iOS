//
//  LoginState.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/8.
//

import Foundation
import SwiftUI

class userInfo: ObservableObject
{
    private enum StorageKey {
        static let savedUsername = "saved_username"
        static let savedNickname = "saved_nickname"
        static let savedCASBound = "saved_cas_bound"
        static let savedBackendBound = "saved_backend_bound"
        static let savedShishanyouniToken = "saved_shishanyouni_token"
    }

    // 使用 @Published，这样当这些值改变时，所有引用的页面都会自动刷新
    @Published var username: String = ""
    @Published var nickname: String = ""
    @Published var plainPassword: String = ""
    @Published var encryptedPasswordSchool: String = ""
    @Published var encryptedPasswordShishanyouni: String = ""
    @Published var shishanyouniToken: String = ""
    @Published var isCASBound: Bool = false
    @Published var isShishanyouniBound: Bool = false

    @Published var showClock: Bool = true
    {
        didSet { UserDefaults.standard.set(showClock, forKey: "pref_showClock") }
    }

    @Published var showEnrollmentDays: Bool = true
    {
        didSet { UserDefaults.standard.set(showEnrollmentDays, forKey: "pref_showEnrollmentDays") }
    }

    // 检测是否在预览环境中运行
    private var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    // 初始化时自动加载保存的数据
    init()
    {

            loadUserInfo()
            showClock = UserDefaults.standard.bool(forKey: "pref_showClock")
            showEnrollmentDays = UserDefaults.standard.bool(forKey: "pref_showEnrollmentDays")
        
    }

    var daysSinceEnrollment: Int?
    {
        // 确保学号长度足够并截取前4位作为年份
        guard username.count >= 4, let year = Int(username.prefix(4))
        else
        {
            return nil
        }

        // 构造入学当年的 9 月 1 日
        var components = DateComponents()
        components.year = year
        components.month = 9
        components.day = 1

        let calendar = Calendar.current
        guard let enrollmentDate = calendar.date(from: components)
        else
        {
            return nil
        }

        // 计算与今天的天数差
        let date1 = calendar.startOfDay(for: enrollmentDate)
        let date2 = calendar.startOfDay(for: Date())

        let componentsDiff = calendar.dateComponents([.day], from: date1, to: date2)

        // 返回天数（入学当天算作第 1 天）
        return (componentsDiff.day ?? 0) + 1
    }

    // 加载保存的学号和密码
    func loadUserInfo()
    {
        #if DEBUG
        if let (devUser, devPass) = loadDevConfig(), !devUser.isEmpty {
            username = devUser
            plainPassword = devPass
            performSchoolEncryption()
            performShishanyouniEncryption()
            isCASBound = true
            isShishanyouniBound = true
            print("✅ 已从 DevConfig.json 自动登录: \(username)")
            return
        }
        #endif

        // 从 UserDefaults 读取学号
        if let savedUsername = UserDefaults.standard.string(forKey: StorageKey.savedUsername),
           !savedUsername.isEmpty
        {
            username = savedUsername

            // 从 Keychain 读取密码
            if let savedPassword = KeychainHelper.shared.get(for: savedUsername)
            {
                if TestAccount.matches(username: savedUsername, password: savedPassword)
                {
                    TestAccount.apply(to: self)
                }
                else
                {
                    plainPassword = savedPassword
                    performSchoolEncryption()
                    performShishanyouniEncryption()
                }
                print("✅ 已自动加载学号: \(username)")
            }
            nickname = UserDefaults.standard.string(forKey: StorageKey.savedNickname) ?? ""
            shishanyouniToken = UserDefaults.standard.string(forKey: StorageKey.savedShishanyouniToken) ?? ""
            if TestAccount.matches(username: username, password: plainPassword)
            {
                updateBindingStatus(casBound: true, shishanyouniBound: true)
            }
            else
            {
                isCASBound = UserDefaults.standard.bool(forKey: StorageKey.savedCASBound)
                isShishanyouniBound = UserDefaults.standard.bool(forKey: StorageKey.savedBackendBound)
            }
        }
        else
        {
            isCASBound = false
            isShishanyouniBound = false
        }
    }

    // 保存学号和密码
    func saveUserInfo()
    {
        guard !username.isEmpty, !plainPassword.isEmpty
        else
        {
            print("学号或密码为空，无法保存")
            return
        }

        // 保存学号到 UserDefaults
        UserDefaults.standard.set(username, forKey: StorageKey.savedUsername)

        // 保存密码到 Keychain
        let success = KeychainHelper.shared.save(password: plainPassword, for: username)

        UserDefaults.standard.set(nickname, forKey: StorageKey.savedNickname)
        UserDefaults.standard.set(shishanyouniToken, forKey: StorageKey.savedShishanyouniToken)
        persistBindingStatus()

        if success
        {
            print("学号和密码已保存")
        }
        else
        {
            print("密码保存失败")
        }
    }

    // 清除保存的数据（退出登录时使用）
    func clearUserInfo()
    {
        // 清除 Keychain 中的密码
        KeychainHelper.shared.delete(for: username)

        // 清除 UserDefaults
        UserDefaults.standard.removeObject(forKey: StorageKey.savedUsername)
        UserDefaults.standard.removeObject(forKey: StorageKey.savedNickname)
        UserDefaults.standard.removeObject(forKey: StorageKey.savedCASBound)
        UserDefaults.standard.removeObject(forKey: StorageKey.savedBackendBound)
        UserDefaults.standard.removeObject(forKey: StorageKey.savedShishanyouniToken)
        UserDefaults.standard.removeObject(forKey: "encrypted_password_school")

        // 清空当前数据
        username = ""
        plainPassword = ""
        encryptedPasswordSchool = ""
        encryptedPasswordShishanyouni = ""
        shishanyouniToken = ""
        nickname = ""
        isCASBound = false
        isShishanyouniBound = false

        print("已清除保存的学号和密码")
    }

    // 仅清除持久化保存的数据，保留当前会话登录态
    func clearSavedCredentials()
    {
        if !username.isEmpty
        {
            KeychainHelper.shared.delete(for: username)
        }

        UserDefaults.standard.removeObject(forKey: StorageKey.savedUsername)
        UserDefaults.standard.removeObject(forKey: StorageKey.savedNickname)
        UserDefaults.standard.removeObject(forKey: StorageKey.savedCASBound)
        UserDefaults.standard.removeObject(forKey: StorageKey.savedBackendBound)
        UserDefaults.standard.removeObject(forKey: StorageKey.savedShishanyouniToken)
        UserDefaults.standard.removeObject(forKey: "encrypted_password_school")

        print("已清除本地保存的账号信息，保留当前会话")
    }

    func updateBindingStatus(casBound: Bool, shishanyouniBound: Bool)
    {
        isCASBound = casBound
        isShishanyouniBound = shishanyouniBound
    }

    func updateShishanyouniToken(_ token: String)
    {
        shishanyouniToken = token
        UserDefaults.standard.set(token, forKey: StorageKey.savedShishanyouniToken)
    }

    // 加密方法
    func performSchoolEncryption()
    {
        if let result = encryptSchoolPassword(password: plainPassword)
        {
            encryptedPasswordSchool = result
            UserDefaults.standard.set(result, forKey: "encrypted_password_school")
        }
    }

    func performShishanyouniEncryption()
    {
        if let result = encryptShishanyouniPassword(password: plainPassword)
        {
            encryptedPasswordShishanyouni = result
        }
    }

    func loadUserNickname()
    {
        nickname = UserDefaults.standard.string(forKey: StorageKey.savedNickname) ?? ""
    }

    func saveUserNickname()
    {
        UserDefaults.standard.set(nickname, forKey: StorageKey.savedNickname)
    }

    func debugprint()
    {
        print("设定为用户名:\(username)\n原始密码为:\(plainPassword)\n加密的密码为:\(encryptedPasswordSchool)")
    }

    private func persistBindingStatus()
    {
        UserDefaults.standard.set(isCASBound, forKey: StorageKey.savedCASBound)
        UserDefaults.standard.set(isShishanyouniBound, forKey: StorageKey.savedBackendBound)
    }

    #if DEBUG
    private func loadDevConfig() -> (String, String)? {
        let configURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()  // Data/
            .deletingLastPathComponent()  // shishanyouni/
            .deletingLastPathComponent()  // project root
            .appendingPathComponent("DevConfig.json")
        guard let data = try? Data(contentsOf: configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let user = json["username"], let pass = json["password"],
              !user.isEmpty, !pass.isEmpty else { return nil }
        return (user, pass)
    }
    #endif
}
