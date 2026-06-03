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

    private enum ScheduleMode: String, CaseIterable, Identifiable
    {
        case personal = "日程"
        case schoolCalendar = "校历"

        var id: String { rawValue }
    }

    var body: some View
    {
        VStack(spacing: 0)
        {
            Picker("切换视图", selection: $selectedMode)
            {
                ForEach(ScheduleMode.allCases)
                { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(Color(.systemGroupedBackground))

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
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
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
