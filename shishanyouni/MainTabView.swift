//
//  MainTabView.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/9.
//

// MainTabView.swift
import SwiftUI
import UIKit

struct MainTabView: View
{
    @EnvironmentObject var userinfo: userInfo

    init()
    {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

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
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(Color(uiColor: .systemBackground), for: .tabBar)
    }
}

#Preview
{
    MainTabView()
        .environmentObject(userInfo())
        .environmentObject(IAPStore(autoload: false))
}

extension View
{
    @ViewBuilder
    func optionalLiquidGlass(enabled: Bool = true,cornerRadius: CGFloat = 64) -> some View
    {
        if #available(iOS 26.0, *)
        {
            if(enabled)
            {
                self.glassEffect(.clear, in: RoundedRectangle(cornerRadius: cornerRadius))
            }
            else
            {
                self
            }
            
        }
        else
        {
            self
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
                                        AdaptiveColors.glassStroke,
                                        AdaptiveColors.glassStrokeBottom,
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
