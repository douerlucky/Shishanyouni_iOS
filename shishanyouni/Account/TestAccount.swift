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
        userinfo.encryptedPasswordShishanyouni = "TEST_ACCOUNT_SHISHANYOUNI_PASSWORD"
        userinfo.updateShishanyouniToken("TEST_ACCOUNT_SHISHANYOUNI_TOKEN")
        userinfo.updateBindingStatus(casBound: true, shishanyouniBound: true)
    }
}
