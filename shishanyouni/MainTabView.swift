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

extension View
{
    @ViewBuilder
    func optionalLiquidGlass() -> some View
    {
        if #available(iOS 26.0, *)
        {
            self
                .glassEffect(.clear)
        }
        else
        {
            self // 老系统什么都不加
        }
    }

    func glassBackground(cornerRadius: CGFloat = 64) -> some View
    {
        modifier(GlassBackground(cornerRadius: cornerRadius))
    }
}

struct GlassBackground: ViewModifier
{
    var cornerRadius: CGFloat = 64

    func body(content: Content) -> some View
    {
        content
            .background(
                Group
                {
                    if #available(iOS 26.0, *)
                    {
                        Color.clear
                            .glassEffect(.regular)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    }
                    else
                    {
                        ZStack
                        {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(.ultraThinMaterial)
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.1),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        }
                    }
                }
            )
    }
}
