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
    // 使用 @Published，这样当这些值改变时，所有引用的页面都会自动刷新
    @Published var username: String = ""
    @Published var nickname: String = ""
    @Published var plainPassword: String = ""
    @Published var encryptedPasswordSchool: String = ""
    @Published var encryptedPasswordShishanyouni: String = ""
    // 初始化时自动加载保存的数据
    init()
    {
        loadUserInfo()
    }

    // 加载保存的学号和密码
    func loadUserInfo()
    {
        // 从 UserDefaults 读取学号
        if let savedUsername = UserDefaults.standard.string(forKey: "saved_username"),
           !savedUsername.isEmpty
        {
            username = savedUsername

            // 从 Keychain 读取密码
            if let savedPassword = KeychainHelper.shared.get(for: savedUsername)
            {
                plainPassword = savedPassword
                performSchoolEncryption()
                performShishanyouniEncryption()
                print("✅ 已自动加载学号: \(username)")
            }
            nickname = UserDefaults.standard.string(forKey: "saved_nickname") ?? ""
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
        UserDefaults.standard.set(username, forKey: "saved_username")

        // 保存密码到 Keychain
        let success = KeychainHelper.shared.save(password: plainPassword, for: username)
        
        UserDefaults.standard.set(nickname, forKey: "saved_nickname")

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
        UserDefaults.standard.removeObject(forKey: "saved_username")
        UserDefaults.standard.removeObject(forKey: "saved_nickname")

        // 清空当前数据
        username = ""
        plainPassword = ""
        encryptedPasswordSchool = ""
        encryptedPasswordShishanyouni = ""
        nickname = ""

        print("已清除保存的学号和密码")
    }

    // 加密方法
    func performSchoolEncryption()
    {
        if let result = encryptSchoolPassword(password: plainPassword)
        {
            encryptedPasswordSchool = result
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
        let nickname = UserDefaults.standard.string(forKey: "saved_nickname")
    }
    
    func saveUserNickname()
    {
        UserDefaults.standard.set(nickname, forKey: "saved_nickname")
    }

    func debugprint()
    {
        print("设定为用户名:\(username)\n原始密码为:\(plainPassword)\n加密的密码为:\(encryptedPasswordSchool)")
    }
    
}
