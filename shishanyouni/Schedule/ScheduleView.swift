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
    @AppStorage("scheduleContentOpacity") private var scheduleContentOpacity: Double = 1.0
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
            Color(.systemGroupedBackground)
                .opacity(scheduleBackgroundEnabled ? 0 : 1)
                .ignoresSafeArea()

            if scheduleBackgroundEnabled, let backgroundImage
            {
                Image(uiImage: backgroundImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .opacity(backgroundOpacity)
            }

            VStack(spacing: 0)
            {
                if showPersonalSchedule
                {
                    Picker("日程模式", selection: $selectedMode)
                    {
                        ForEach(availableModes)
                        { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    .opacity(scheduleContentOpacity)
                    .padding(.horizontal, 12)
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
            .padding(.top, scheduleBackgroundEnabled ? 72 : 0)
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
        guard !backgroundImageFilename.isEmpty
        else
        {
            backgroundImage = nil
            return
        }

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(backgroundImageFilename)

        if let data = try? Data(contentsOf: documentsURL),
           let image = UIImage(data: data)
        {
            backgroundImage = image
            return
        }

        if let sharedURL = CurriculumWidgetSync.appGroupContainerURL()?.appendingPathComponent(backgroundImageFilename),
           let data = try? Data(contentsOf: sharedURL),
           let image = UIImage(data: data)
        {
            backgroundImage = image
            return
        }

        backgroundImage = nil
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
