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
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(PreferenceKey.lastShownWhatsNewVersion) private var lastShownWhatsNewVersion = ""
    @AppStorage(PreferenceKey.appDisplayMode) private var displayModeRaw = AppDisplayMode.all.rawValue
    @AppStorage(PreferenceKey.showScheduleTab) private var showScheduleTab = true
    @AppStorage(PreferenceKey.showPersonalSchedule) private var showPersonalSchedule = true
    @AppStorage(PreferenceKey.showCampusPassFeatures) private var showCampusPassFeatures = true
    @State private var showWhatsNew = false

    private var isScheduleTabVisible: Bool
    {
        showScheduleTab
    }

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
        TabView(selection: $userinfo.selectedTab)
        {
            if isScheduleTabVisible
            {
                NavigationStack
                {
                    ScheduleView()
                }
                .tabItem
                {
                    Label(showPersonalSchedule ? "日程与校历" : "校历", systemImage: "calendar.badge.clock")
                }
                .tag(0)
            }

            NavigationStack
            {
                CurriculumView()
            }
            .tabItem
            {
                Label("课表", systemImage: "calendar")
            }
            .tag(1)

            // 首页
            NavigationStack
            {
                HomeView()
            }
            .tabItem
            {
                Label("首页", systemImage: "house.fill")
            }
            .tag(2)

            // 个人中心
            NavigationStack
            {
                ProfileView()
            }
            .tabItem
            {
                Label("我的", systemImage: "person.fill")
            }
            .tag(3)
        }
        .accentColor(.blue)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(Color(uiColor: .systemBackground), for: .tabBar)
        .onChange(of: scenePhase)
        { phase in
            guard phase == .active else { return }
            Task
            {
                await IAPStore.shared.refreshEntitlements()
            }
        }
        .onAppear
        {
            migrateLegacyFeatureDisplayModeIfNeeded()
            keepSelectionAvailableInCurrentMode()
            showWhatsNewIfNeeded()
        }
        .onChange(of: showScheduleTab)
        { _ in
            keepSelectionAvailableInCurrentMode()
        }
        .sheet(isPresented: $showWhatsNew)
        {
            if #available(iOS 17.0, *)
            {
                WhatsNewView
                {
                    lastShownWhatsNewVersion = currentWhatsNewVersion
                    showWhatsNew = false
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var currentWhatsNewVersion: String
    {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(version)-\(build)"
    }

    /// 升级自旧版“简洁模式 / 无通行证内容”时，补齐新增的独立通行证开关。
    private func migrateLegacyFeatureDisplayModeIfNeeded()
    {
        switch displayModeRaw
        {
        case "simple":
            showCampusPassFeatures = false
            displayModeRaw = AppDisplayMode.noCampusPassContent.rawValue
        case "complete":
            displayModeRaw = AppDisplayMode.all.rawValue
        case AppDisplayMode.noCampusPassContent.rawValue:
            showCampusPassFeatures = false
        default:
            break
        }
    }

    private func showWhatsNewIfNeeded()
    {
        guard #available(iOS 17.0, *) else { return }
        guard lastShownWhatsNewVersion != currentWhatsNewVersion else { return }

        showWhatsNew = true
    }

    private func keepSelectionAvailableInCurrentMode()
    {
        guard !isScheduleTabVisible else { return }

        if userinfo.selectedTab == 0
        {
            userinfo.selectedTab = 1
        }

        if userinfo.defaultTab == 0
        {
            userinfo.defaultTab = 1
        }
    }
}

#Preview
{
    MainTabView()
        .environmentObject(userInfo())
        .environmentObject(IAPStore.preview(hasActiveSubscription: false))
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
