// App 显示模式设置。

import SwiftUI

/// App 模式统一设置：页面、通行证内容和首页信息在这里管理。
struct AppModeSettingView: View
{
    @EnvironmentObject private var userinfo: userInfo
    @AppStorage(PreferenceKey.appDisplayMode) private var displayModeRaw = AppDisplayMode.all.rawValue
    @AppStorage(PreferenceKey.showScheduleTab) private var showScheduleTab = true
    @AppStorage(PreferenceKey.showPersonalSchedule) private var showPersonalSchedule = true
    @AppStorage(PreferenceKey.showCampusPassFeatures) private var showCampusPassFeatures = true
    @AppStorage(PreferenceKey.showCampusPassCard) private var showCampusPassCard = true

    private var displayMode: AppDisplayMode
    {
        AppDisplayMode.fromStoredValue(displayModeRaw)
    }

    var body: some View
    {
        List
        {
            Section("显示模式")
            {
                Picker("模式", selection: $displayModeRaw)
                {
                    ForEach(AppDisplayMode.allCases)
                    { mode in
                        Text(mode.title)
                            .tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 4)
                {
                    Text(displayMode.title)
                        .font(.subheadline.weight(.semibold))
                    Text(displayMode.description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section
            {
                Toggle("显示日程与校历 Tab", isOn: $showScheduleTab)
                Toggle("显示日程", isOn: $showPersonalSchedule)
                    .disabled(!showScheduleTab || !showCampusPassFeatures)
            } header: {
                Text("Tab 页面")
            } footer: {
                Text(displayMode == .custom
                     ? "关闭“显示日程”后，该 Tab 仅保留校历。"
                     : "预设模式会自动管理日程与校历。")
            }
            .disabled(displayMode != .custom)

            Section
            {
                Toggle("显示日期与时钟", isOn: $userinfo.showClock)
                Toggle("显示入校天数", isOn: $userinfo.showEnrollmentDays)
                Toggle("显示下一个安排", isOn: $userinfo.showNextEvent)
            } header: {
                Text("首页内容")
            } footer: {
                Text(displayMode == .custom
                     ? "可按需显示日期时钟、入校天数和下一个安排。"
                     : "预设模式会自动管理首页内容。")
            }
            .disabled(displayMode != .custom)

            Section
            {
                Toggle("显示通行证功能", isOn: $showCampusPassFeatures)
                Toggle("显示“我的”页面里的通行证卡片", isOn: $showCampusPassCard)
                    .disabled(!showCampusPassFeatures)
            } footer: {
                Text(displayMode == .custom
                     ? "关闭通行证功能后，付费墙和所有需要通行证的功能入口都不会显示。"
                     : "预设模式会自动管理通行证功能。")
            }
            .disabled(displayMode != .custom)
        }
        .navigationTitle("功能显示设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .listStyle(.insetGrouped)
        .onAppear
        {
            migrateLegacyModeIfNeeded()
        }
        .onChange(of: displayModeRaw)
        { _ in
            applySelectedMode()
        }
    }

    private func migrateLegacyModeIfNeeded()
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

    /// 模式只提供通行证展示的快捷预设，不能覆盖用户已经选好的校历和首页内容。
    private func applySelectedMode()
    {
        switch displayMode
        {
        case .all:
            showCampusPassFeatures = true
            showCampusPassCard = true
            showScheduleTab = true
            showPersonalSchedule = true
            userinfo.showClock = true
            userinfo.showEnrollmentDays = true
            userinfo.showNextEvent = true
        case .noCampusPassContent:
            showCampusPassFeatures = false
            showCampusPassCard = false
            showScheduleTab = false
            showPersonalSchedule = false
            userinfo.showClock = true
            userinfo.showEnrollmentDays = true
            userinfo.showNextEvent = true
        case .custom:
            break
        }
    }
}
