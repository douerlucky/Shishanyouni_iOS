//
//  ScheduleView.swift
//  shishanyouni
//
//  用户日程入口：在个人日程和学校校历之间切换。
//

import SwiftUI

struct ScheduleView: View
{
    @State private var selectedMode: ScheduleMode = .personal
    @State private var backgroundImage: UIImage?

    @AppStorage("scheduleBackgroundImageFilename") private var backgroundImageFilename = ""
    @AppStorage("scheduleBackgroundOpacity") private var backgroundOpacity: Double = 0.2
    @AppStorage("scheduleBackgroundEnabled") private var scheduleBackgroundEnabled: Bool = false
    @AppStorage(PreferenceKey.showPersonalSchedule) private var showPersonalSchedule = true

    private enum ScheduleMode: String, CaseIterable, Identifiable
    {
        case personal = "日程"
        case schoolCalendar = "校历"

        var id: String { rawValue }
    }

    private var availableModes: [ScheduleMode]
    {
        showPersonalSchedule ? ScheduleMode.allCases : [.schoolCalendar]
    }

    var body: some View
    {
        ZStack
        {
            PageBackgroundView(
                image: backgroundImage,
                isEnabled: scheduleBackgroundEnabled,
                opacity: backgroundOpacity
            )

            VStack(spacing: 0)
            {
                if showPersonalSchedule
                {
                    Picker("日程模式", selection: $selectedMode)
                    {
                        ForEach(availableModes)
                        { mode in
                            Text(mode.rawValue).appTextOpacity().tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 6)
                }

                Group
                {
                    switch selectedMode
                    {
                    case .personal:
                        PersonalScheduleView()
                    case .schoolCalendar:
                        SchoolCalendarView()
                    }
                }
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .navigationTitle(showPersonalSchedule ? "日程" : "校历")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear
        {
            loadScheduleBackgroundImage()
            if !showPersonalSchedule
            {
                selectedMode = .schoolCalendar
            }
        }
        .onChange(of: backgroundImageFilename)
        { _ in
            loadScheduleBackgroundImage()
        }
        .onChange(of: showPersonalSchedule)
        { isVisible in
            if !isVisible
            {
                selectedMode = .schoolCalendar
            }
        }
    }

    private func loadScheduleBackgroundImage()
    {
        backgroundImage = BackgroundImageStore.loadImage(named: backgroundImageFilename)
    }
}

#if DEBUG
#Preview("日程入口")
{
    NavigationStack
    {
        ScheduleView()
            .environmentObject(userInfo())
            .environmentObject(IAPStore.preview(hasActiveSubscription: false))
    }
}
#endif
