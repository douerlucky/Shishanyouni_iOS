//
//  shishanyouniApp.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/4.
//

import SwiftUI

@main
struct shishanyouniApp: App
{
    @StateObject private var userinfo = userInfo()
    @StateObject private var iapStore = IAPStore()
    
    var body: some Scene
    {
        WindowGroup
        {
            MainTabView()
                .environmentObject(userinfo)
                .environmentObject(iapStore)
        }
    }
}

// 默认配色集
struct DefaultAppColor {
    // 橙红色系
    static let orangeRed = Color(red: 255/255.0, green: 117/255.0, blue: 0/255.0)      // #FF7500 - 橙红色/橘红色
    static let hotPink = Color(red: 239/255.0, green: 91/255.0, blue: 156/255.0)      // #ef5b9c - 艳粉色/玫红色
    static let coralRed = Color(red: 241/255.0, green: 91/255.0, blue: 108/255.0)     // #f15b6c - 珊瑚红
    static let orange = Color(red: 242/255.0, green: 101/255.0, blue: 34/255.0)       // #f26522 - 橙色
    static let brown = Color(red: 165/255.0, green: 103/255.0, blue: 63/255.0)        // #a5673f - 棕色/咖啡色
    // 紫色系
    static let purple = Color(red: 133/255.0, green: 82/255.0, blue: 161/255.0)       // #8552a1 - 紫色
    static let violet = Color(red: 141/255.0, green: 75/255.0, blue: 187/255.0)       // #8d4bbb - 紫罗兰色
    static let magenta = Color(red: 255/255.0, green: 0/255.0, blue: 151/255.0)       // #ff0097 - 品红色/洋红色
    static let dustyPurple = Color(red: 114/255.0, green: 94/255.0, blue: 130/255.0)  // #725e82 - 暗紫色/灰紫色
    // 绿色系
    static let limeGreen = Color(red: 127/255.0, green: 184/255.0, blue: 14/255.0)    // #7fb80e - 石灰绿/亮绿
    static let mintGreen = Color(red: 101/255.0, green: 194/255.0, blue: 148/255.0)   // #65c294 - 薄荷绿
    static let oliveGreen = Color(red: 120/255.0, green: 146/255.0, blue: 98/255.0)   // #789262 - 橄榄绿
    // 蓝色系
    static let skyBlue = Color(red: 51/255.0, green: 163/255.0, blue: 220/255.0)      // #33a3dc - 天蓝色/亮蓝
    static let turquoise = Color(red: 120/255.0, green: 205/255.0, blue: 209/255.0)   // #78cdd1 - 绿松石蓝/浅青蓝
    // 黄色/米色
    static let beige = Color(red: 209/255.0, green: 186/255.0, blue: 116/255.0)       // #D1BA74 - 米色/浅黄
}
