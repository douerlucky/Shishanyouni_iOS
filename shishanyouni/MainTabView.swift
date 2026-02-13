//
//  MainTabView.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/9.
//

// MainTabView.swift
import SwiftUI

struct MainTabView: View
{
    @EnvironmentObject var userinfo: userInfo

    var body: some View
    {
        TabView
        {
            NavigationStack
            {
                ScheduleView()
            }
            .tabItem
            {
                Label("课表", systemImage: "calendar")
            }
            // 首页
            NavigationStack
            {
                HomeView()
            }
            .tabItem
            {
                Label("首页", systemImage: "house.fill")
            }

            // 个人中心
            NavigationStack
            {
                ProfileView()
            }
            .tabItem
            {
                Label("我的", systemImage: "person.fill")
            }
        }
        .accentColor(.blue)
    }
}

#Preview
{
    MainTabView()
        .environmentObject(userInfo())
}
