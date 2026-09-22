//
//  ProfileView.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/9.
//

import SwiftUI

struct ProfileView: View
{
    @EnvironmentObject var userinfo: userInfo
    @EnvironmentObject var iapStore: IAPStore
    @State private var navigateToSubscription = false
    @State private var showWhatsNew = false
    @AppStorage(PreferenceKey.showCampusPassFeatures) private var showCampusPassFeatures = true
    @AppStorage(PreferenceKey.showCampusPassCard) private var showCampusPassCard = true

    private var hidesCampusPassContent: Bool
    {
        !showCampusPassFeatures
    }

    var greeting: String
    {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour
        {
        case 0 ..< 2: return "凌晨好，还在卷吗"
        case 2 ..< 5: return "这么晚了，还不睡吗"
        case 5 ..< 9: return "早上好"
        case 9 ..< 11: return "上午好"
        case 11 ..< 13: return "中午好"
        case 13 ..< 14: return "中午好，午睡了吗"
        case 14 ..< 17: return "下午好"
        case 17 ..< 19: return "下午好，吃饭了吗"
        case 19 ..< 21: return "晚上好"
        case 21 ..< 24: return "晚上好，今天辛苦了"
        default: return "你好"
        }
    }

    var body: some View
    {
        List
        {
            VStack(spacing: 16)
            {
                if userinfo.username.isEmpty
                {
                    VStack(spacing: 8)
                    {
                        Text("当前为游客模式")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)

                        Text("公开信息与本地工具功能均可正常使用")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)

                        Text("绑定信息门户后可使用成绩、考试、体测等个性化校园服务")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                else if !userinfo.nickname.isEmpty
                {
                    Text("\(greeting)，\(userinfo.nickname)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                else
                {
                    Text("\(greeting)，\(userinfo.username)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
            }
            .listRowBackground(Color.clear)

            // 第一组：账号信息
            Section
            {
                HStack(spacing: 15)
                {
                    // 模拟设置里的彩色图标
                    Image(systemName: "person.fill")
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.blue) // 蓝色背景
                        .cornerRadius(6)

                    NavigationLink
                    {
                        LoginView()
                    } label:
                    {
                        VStack(alignment: .leading)
                        {
                            Text("账号设置")
                                .font(.body)
                            if userinfo.username.isEmpty
                            {
                                Text("点击绑定信息门户账号")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            else if userinfo.isCASBound && userinfo.isShishanyouniBound
                            {
                                Text("已绑定学校账号")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            else if userinfo.isCASBound
                            {
                                Text("CAS已绑定，狮山有你未绑定")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            else if userinfo.isShishanyouniBound
                            {
                                Text("狮山有你已绑定，CAS未绑定")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            else
                            {
                                Text("未成功绑定狮山有你、CAS账号")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }

            if !hidesCampusPassContent && showCampusPassCard
            {
            Section
            {
                Button
                {
                    navigateToSubscription = true
                } label: {
                    VStack(alignment: .leading, spacing: 14)
                    {
                        HStack(spacing: 14)
                        {
                            ZStack
                            {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(red: 23 / 255, green: 144 / 255, blue: 204 / 255).opacity(0.14))
                                    .frame(width: 52, height: 52)

                                Image(systemName: iapStore.hasActiveSubscription ? "checkmark.shield.fill" : "crown.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(Color(red: 23 / 255, green: 144 / 255, blue: 204 / 255))
                            }

                            VStack(alignment: .leading, spacing: 8)
                            {
                                Text("校园通行证")
                                    .font(.system(size: 19, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)

                                Text(
                                    iapStore.hasActiveSubscription
                                    ? "狮山有你iOS校园通行证用户，可使用狮山有你全部功能"
                                    : "订阅狮山有你iOS校园通行证，畅享所有功能"
                                )
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                            }

                            Spacer(minLength: 0)
                        }

                        Text(iapStore.hasActiveSubscription ? "已开通" : "立即开通")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(iapStore.hasActiveSubscription ? Color.green : Color(red: 23 / 255, green: 144 / 255, blue: 204 / 255))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                (iapStore.hasActiveSubscription ? Color.green : Color(red: 23 / 255, green: 144 / 255, blue: 204 / 255))
                                    .opacity(0.12),
                                in: Capsule()
                            )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(Color(red: 23 / 255, green: 144 / 255, blue: 204 / 255).opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(
                                Color(red: 23 / 255, green: 144 / 255, blue: 204 / 255).opacity(0.12),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            }

            if #available(iOS 17.0, *)
            {
                Section(header: Text("新功能"))
                {
                    Button
                    {
                        showWhatsNew = true
                    } label: {
                        HStack(spacing: 15)
                        {
                            Image(systemName: "sparkles")
                                .foregroundColor(.white)
                                .frame(width: 30, height: 30)
                                .background(Color.orange)
                                .cornerRadius(6)

                            VStack(alignment: .leading, spacing: 2)
                            {
                                Text("查看新功能")
                                    .foregroundColor(.primary)
                                Text("看看这次更新了什么")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundColor(Color(.systemGray3))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            // 第二组：设置入口；具体内容分别放入独立子页面。
            Section(header: Text("设置"))
            {
                NavigationLink
                {
                    AppModeSettingView()
                } label: {
                    ProfileSettingRow(
                        title: "功能显示设置",
                        icon: "rectangle.3.group.fill",
                        color: .indigo
                    )
                }

                NavigationLink
                {
                    CurriculumFontSettingView()
                } label: {
                    ProfileSettingRow(
                        title: "调整课表显示字体",
                        icon: "textformat.size",
                        color: .purple
                    )
                }

                NavigationLink
                {
                    PersonalizationSettingView()
                } label: {
                    ProfileSettingRow(
                        title: "个性化设置",
                        icon: "paintpalette.fill",
                        color: .pink
                    )
                }

                if !hidesCampusPassContent
                {
                    NavigationLink
                    {
                        WidgetSettingView()
                    } label: {
                        ProfileSettingRow(
                            title: "小组件",
                            icon: "widget.large.badge.plus",
                            color: .orange
                        )
                    }
                }

                NavigationLink
                {
                    AboutUs()
                } label: {
                    ProfileSettingRow(
                        title: "关于狮山有你iOS",
                        icon: "info.circle.fill",
                        color: .blue
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("我的")
        .navigationDestination(isPresented: $navigateToSubscription)
        {
            SubscriptionView()
        }
        .sheet(isPresented: $showWhatsNew)
        {
            if #available(iOS 17.0, *)
            {
                WhatsNewView
                {
                    showWhatsNew = false
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            else
            {
                Text("新功能介绍需要 iOS 17 或更高版本")
                    .font(.headline)
                    .padding()
            }
        }
    }
}

/// “我的”页所有设置入口共用的图标样式。
///
/// 用彩色底块承载白色图标，避免外层设置与个性化设置混用线条／填充两套视觉语言。
private struct ProfileSettingRow: View
{
    let title: String
    let icon: String
    let color: Color
    var showsChevron = false

    var body: some View
    {
        HStack(spacing: 15)
        {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(color, in: RoundedRectangle(cornerRadius: 6))

            Text(title)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            if showsChevron
            {
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

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

/// 昵称、组件、背景和默认启动页面的个人偏好子页面。
struct PersonalizationSettingView: View
{
    @EnvironmentObject private var userinfo: userInfo
    @AppStorage(PreferenceKey.showScheduleTab) private var showScheduleTab = true
    @State private var showNicknameAlert = false
    @State private var tempNickname = ""

    private var canSelectScheduleAsDefault: Bool
    {
        showScheduleTab
    }

    var body: some View
    {
        List
        {
            Section("个性化设置")
            {
                Button
                {
                    tempNickname = userinfo.nickname
                    showNicknameAlert = true
                } label: {
                    ProfileSettingRow(
                        title: "昵称设置",
                        icon: "person.crop.circle.fill",
                        color: .blue,
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)

                NavigationLink
                {
                    BackgroundSettingView()
                } label: {
                    ProfileSettingRow(
                        title: "背景图片设置",
                        icon: "photo.fill",
                        color: .teal
                    )
                }

                Picker(selection: $userinfo.defaultTab)
                {
                    if canSelectScheduleAsDefault
                    {
                        Text("课表与校历").tag(0)
                    }
                    Text("课表").tag(1)
                    Text("首页").tag(2)
                    Text("我的").tag(3)
                } label: {
                    ProfileSettingRow(
                        title: "默认启动页面",
                        icon: "house.fill",
                        color: .orange
                    )
                }
            }
        }
        .navigationTitle("个性化设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .listStyle(.insetGrouped)
        .onAppear
        {
            keepDefaultTabAvailable()
        }
        .onChange(of: showScheduleTab)
        { _ in
            keepDefaultTabAvailable()
        }
        .alert("昵称设置", isPresented: $showNicknameAlert)
        {
            TextField("输入你的昵称", text: $tempNickname)
                .textInputAutocapitalization(.never)

            Button("取消", role: .cancel) { }
            Button("确定")
            {
                userinfo.nickname = tempNickname
                userinfo.saveUserInfo()
            }
        } message: {
            Text("请输入你想使用的昵称")
        }
    }

    private func keepDefaultTabAvailable()
    {
        if !canSelectScheduleAsDefault && userinfo.defaultTab == 0
        {
            userinfo.defaultTab = 1
        }
    }
}

/// 只负责课表字体大小；App 模式已经独立到 AppModeSettingView。
struct CurriculumFontSettingView: View
{
    @AppStorage(PreferenceKey.curriculumFontScale) private var curriculumFontScale: Double = 1.0

    var body: some View
    {
        List
        {
            Section("预览")
            {
                VStack(spacing: 6)
                {
                    Text("Akie秋绘的直播鉴赏")
                        .font(.system(size: 12 * curriculumFontScale, weight: .bold))
                    HStack(spacing: 4)
                    {
                        Image(systemName: "location.fill")
                        Text("四教A126")
                    }
                    .font(.system(size: 10 * curriculumFontScale))
                    HStack(spacing: 4)
                    {
                        Image(systemName: "person.fill")
                        Text("douer_lucky")
                    }
                    .font(.system(size: 9 * curriculumFontScale))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
            }

            Section
            {
                VStack(alignment: .leading, spacing: 8)
                {
                    Text("字体大小：\(Int(curriculumFontScale * 100))%")
                        .font(.subheadline)
                    Slider(value: $curriculumFontScale, in: 0.8 ... 1.5, step: 0.05)
                }

                Button("恢复默认大小")
                {
                    curriculumFontScale = 1.0
                }
                .frame(maxWidth: .infinity)
            } header: {
                Text("课表显示字体")
            } footer: {
                Text("字号变大时，课表单元格高度会同步增加，课程名称、教室和老师会尽量完整显示。")
            }
        }
        .navigationTitle("调整课表显示字体")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .listStyle(.insetGrouped)
    }
}

#Preview
{
    ProfileView()
        .environmentObject(userInfo())
        .environmentObject(IAPStore.preview(hasActiveSubscription: false))
}
