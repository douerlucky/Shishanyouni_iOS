import Foundation
import SwiftUI

/// 账号状态与本地密码。V3 门户、子系统凭据由独立的 Keychain Store 管理。
class userInfo: ObservableObject
{
    private enum StorageKey
    {
        static let savedUsername = "saved_username"
        static let savedNickname = "saved_nickname"
        static let savedCASBound = "saved_cas_bound"
        static let savedBackendBound = "saved_backend_bound"
        static let rememberPassword = "remember_account_password"
    }

    @Published var username = ""
    @Published var nickname = ""
    @Published var plainPassword = ""
    @Published var encryptedPasswordSchool = ""
    @Published var encryptedPasswordShishanyouni = ""
    @Published var isCASBound = false
    @Published var isShishanyouniBound = false
    @Published var showClock = true { didSet { UserDefaults.standard.set(showClock, forKey: "pref_showClock") } }
    @Published var showEnrollmentDays = true { didSet { UserDefaults.standard.set(showEnrollmentDays, forKey: "pref_showEnrollmentDays") } }
    @Published var showNextEvent = true { didSet { UserDefaults.standard.set(showNextEvent, forKey: "pref_showNextEvent") } }
    @Published var defaultTab = 1 { didSet { UserDefaults.standard.set(defaultTab, forKey: "pref_defaultTab") } }
    @Published var selectedTab = 1

    private var backendObserver: NSObjectProtocol?

    var remembersPassword: Bool
    {
        UserDefaults.standard.object(forKey: StorageKey.rememberPassword) as? Bool ?? true
    }

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
        backendObserver = NotificationCenter.default.addObserver(
            forName: .shishanyouniV3CredentialsChanged, object: nil, queue: .main
        )
        { [weak self] notification in
            guard let self, notification.object as? String == self.username else { return }
            self.isShishanyouniBound = ShishanyouniV3CredentialStore().load(username: self.username) != nil
            if UserDefaults.standard.string(forKey: StorageKey.savedUsername) == self.username
            {
                UserDefaults.standard.set(self.isShishanyouniBound, forKey: StorageKey.savedBackendBound)
            }
        }
    }

    deinit
    {
        if let backendObserver { NotificationCenter.default.removeObserver(backendObserver) }
    }

    var daysSinceEnrollment: Int?
    {
        guard username.count >= 4, let year = Int(username.prefix(4)) else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = 9
        components.day = 1
        guard let date = Calendar.current.date(from: components) else { return nil }
        return (Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: date), to: Calendar.current.startOfDay(for: Date())).day ?? 0) + 1
    }

    /// 冷启动只读取本地状态，不 bind，不用 expireAt 自行判定服务端凭据失效。
    func loadUserInfo()
    {
        #if DEBUG
        if let (devUser, devPassword) = loadDevConfig(), !devUser.isEmpty
        {
            username = devUser
            plainPassword = devPassword
            performSchoolEncryption()
            performShishanyouniEncryption()
            isCASBound = true
            isShishanyouniBound = ShishanyouniV3CredentialStore().load(username: username) != nil
            return
        }
        #endif
        guard let saved = UserDefaults.standard.string(forKey: StorageKey.savedUsername), !saved.isEmpty else { return }
        username = saved
        if let password = KeychainHelper.shared.get(for: saved)
        {
            plainPassword = password
            performSchoolEncryption()
            performShishanyouniEncryption()
        }
        nickname = UserDefaults.standard.string(forKey: StorageKey.savedNickname) ?? ""
        isCASBound = UserDefaults.standard.bool(forKey: StorageKey.savedCASBound)
        isShishanyouniBound = ShishanyouniV3CredentialStore().load(username: saved) != nil
    }

    /// “记住密码”只控制密码，不能顺带删除可继续使用的 V3 登录凭据。
    func saveUserInfo(rememberPassword: Bool? = nil)
    {
        guard !username.isEmpty else { return }
        let remember = rememberPassword ?? remembersPassword
        UserDefaults.standard.set(remember, forKey: StorageKey.rememberPassword)
        UserDefaults.standard.set(username, forKey: StorageKey.savedUsername)
        UserDefaults.standard.set(nickname, forKey: StorageKey.savedNickname)
        if remember
        {
            if !plainPassword.isEmpty { _ = KeychainHelper.shared.save(password: plainPassword, for: username) }
        }
        else
        {
            KeychainHelper.shared.delete(for: username)
        }
        persistBindingStatus()
    }

    @MainActor
    func clearUserInfo() async
    {
        let account = username
        _ = await ShishanyouniV3Session.shared.signOut(username: account)
        if !account.isEmpty { KeychainHelper.shared.delete(for: account) }
        for key in [
            StorageKey.savedUsername, StorageKey.savedNickname, StorageKey.savedCASBound,
            StorageKey.savedBackendBound, StorageKey.rememberPassword,
            "saved_shishanyouni_token", "encrypted_password_school"
        ]
        {
            UserDefaults.standard.removeObject(forKey: key)
        }
        username = ""
        nickname = ""
        plainPassword = ""
        encryptedPasswordSchool = ""
        encryptedPasswordShishanyouni = ""
        isCASBound = false
        isShishanyouniBound = false
    }

    func updateBindingStatus(casBound: Bool, shishanyouniBound: Bool)
    {
        isCASBound = casBound
        isShishanyouniBound = shishanyouniBound
    }

    func performSchoolEncryption()
    {
        encryptedPasswordSchool = encryptSchoolPassword(password: plainPassword) ?? ""
    }

    func performShishanyouniEncryption()
    {
        encryptedPasswordShishanyouni = encryptShishanyouniPassword(password: plainPassword) ?? ""
    }

    func loadUserNickname() { nickname = UserDefaults.standard.string(forKey: StorageKey.savedNickname) ?? "" }
    func saveUserNickname() { UserDefaults.standard.set(nickname, forKey: StorageKey.savedNickname) }

    func debugprint()
    {
        #if DEBUG
        print("账号状态：已填写学号=\(!username.isEmpty)，已填写密码=\(!plainPassword.isEmpty)，已绑定学校=\(isCASBound)，已绑定后端=\(isShishanyouniBound)")
        #endif
    }

    private func persistBindingStatus()
    {
        UserDefaults.standard.set(isCASBound, forKey: StorageKey.savedCASBound)
        UserDefaults.standard.set(isShishanyouniBound, forKey: StorageKey.savedBackendBound)
    }

    #if DEBUG
    private func loadDevConfig() -> (String, String)?
    {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: directory.appendingPathComponent("shishanyouni.xcodeproj").path)
        {
            let parent = directory.deletingLastPathComponent()
            guard parent != directory else { return nil }
            directory = parent
        }
        let configURL = directory.appendingPathComponent("DevConfig.json")
        guard let data = try? Data(contentsOf: configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let username = json["username"], let password = json["password"],
              !username.isEmpty, !password.isEmpty else { return nil }
        return (username, password)
    }
    #endif
}
