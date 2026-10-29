//
//  TestAccount.swift
//  shishanyouni
//
//  Created by Codex on 2026/5/12.
//

import Foundation

enum TestAccount
{
    static let username = "2023012610000"
    static let password = "Akie0126@"

    static func matches(username: String, password: String) -> Bool
    {
        username.trimmingCharacters(in: .whitespacesAndNewlines) == Self.username
            && password == Self.password
    }

    static func apply(to userinfo: userInfo)
    {
        userinfo.username = Self.username
        userinfo.plainPassword = Self.password
        userinfo.encryptedPasswordSchool = "TEST_ACCOUNT_SCHOOL_PASSWORD"
        // 本地学校直连演示仍保留；后端必须取得真正的 V3 凭据，不能伪造登录成功。
        userinfo.performShishanyouniEncryption()
        userinfo.updateBindingStatus(
            casBound: true,
            shishanyouniBound: ShishanyouniV3CredentialStore().load(username: Self.username) != nil
        )
    }
}
