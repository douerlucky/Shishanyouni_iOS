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
    @Published var plainPassword: String = ""
    @Published var encryptedResult: String = ""

    // 加密方法
    func performEncryption()
    {
        if let result = encryptPassword(password: plainPassword)
        {
            encryptedResult = result
        }
    }
    func debugprint()
    {
        print("设定为用户名:\(username)\n原始密码为:\(plainPassword)\n加密的密码为:\(encryptedResult)")
    }
}
