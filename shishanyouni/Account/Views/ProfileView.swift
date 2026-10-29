// “我的”页面；设置页面位于 Setting。

import SwiftUI

struct ProfileView: View
{
    @EnvironmentObject var userinfo: userInfo
    @EnvironmentObject var iapStore: IAPStore
    @State private var navigateToSubscription = false
    @State private var showWhatsNew = false
    @State private var backgroundImage: UIImage?
    @AppStorage(PreferenceKey.showCampusPassFeatures) private var showCampusPassFeatures = true
    @AppStorage(PreferenceKey.showCampusPassCard) private var showCampusPassCard = true
    @AppStorage(PreferenceKey.scheduleBackgroundImageFilename) private var backgroundImageFilename = ""
    @AppStorage(PreferenceKey.scheduleBackgroundOpacity) private var backgroundOpacity: Double = 0.2
    @AppStorage(PreferenceKey.profileBackgroundEnabled) private var profileBackgroundEnabled = false

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
        ZStack
        {
            PageBackgroundView(
                image: backgroundImage,
                isEnabled: profileBackgroundEnabled,
                opacity: backgroundOpacity
            )

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
                            .appTextOpacity()

                        Text("公开信息与本地工具功能均可正常使用")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .appTextOpacity()

                        Text("绑定信息门户后可使用成绩、考试、体测等个性化校园服务")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .appTextOpacity()
                    }
                }
                else if !userinfo.nickname.isEmpty
                {
                    Text("\(greeting)，\(userinfo.nickname)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .appTextOpacity()
                }
                else
                {
                    Text("\(greeting)，\(userinfo.username)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .appTextOpacity()
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
                        .background { Color.blue.componentBackgroundOpacity() }
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
                                .appTextOpacity()
                            if userinfo.username.isEmpty
                            {
                                Text("点击绑定\(SchoolServiceName.unifiedIdentity)账号")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .appTextOpacity()
                            }
                            else if userinfo.isCASBound && userinfo.isShishanyouniBound
                            {
                                Text("已绑定学校账号")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .appTextOpacity()
                            }
                            else if userinfo.isCASBound
                            {
                                Text("\(SchoolServiceName.unifiedIdentity)已绑定，狮山有你未绑定")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .appTextOpacity()
                            }
                            else if userinfo.isShishanyouniBound
                            {
                                Text("狮山有你已绑定，\(SchoolServiceName.unifiedIdentity)未绑定")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .appTextOpacity()
                            }
                            else
                            {
                                Text("未成功绑定狮山有你、\(SchoolServiceName.unifiedIdentity)账号")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .appTextOpacity()
                            }
                        }
                    }
                }
            }

            if !hidesCampusPassContent && showCampusPassCard
            {
            Section
            {
                let cardShape = RoundedRectangle(cornerRadius: 22, style: .continuous)
                let iconShape = RoundedRectangle(cornerRadius: 16, style: .continuous)
                let campusPassTint = Color(red: 23 / 255, green: 144 / 255, blue: 204 / 255)

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
                                iconShape
                                    .fill(campusPassTint.opacity(0.14))
                                    .componentBackgroundOpacity()
                                    .frame(width: 52, height: 52)

                                Image(systemName: iapStore.hasActiveSubscription ? "checkmark.shield.fill" : "crown.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(campusPassTint)
                            }

                            VStack(alignment: .leading, spacing: 8)
                            {
                                Text("校园通行证")
                                    .font(.system(size: 19, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .appTextOpacity()

                                Text(
                                    iapStore.hasActiveSubscription
                                    ? "狮山有你iOS校园通行证用户，可使用狮山有你iOS全部功能"
                                    : "订阅狮山有你iOS校园通行证，畅享所有功能"
                                )
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .appTextOpacity()
                            }

                            Spacer(minLength: 0)
                        }

                        Text(iapStore.hasActiveSubscription ? "已开通" : "立即开通")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(iapStore.hasActiveSubscription ? Color.green : campusPassTint)
                            .appTextOpacity()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background
                            {
                                Capsule()
                                    .fill((iapStore.hasActiveSubscription ? Color.green : campusPassTint).opacity(0.12))
                                    .componentBackgroundOpacity()
                            }
                    }
                    // 原来的白边 inset 已经在下面通过 listRowInsets 清零；
                    // 这里把蓝色底的 padding 补齐到原白边的宽度，让蓝色铺满整行。
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background
                    {
                        cardShape.fill(Color(uiColor: .secondarySystemGroupedBackground))
                            .overlay(cardShape.fill(campusPassTint.opacity(0.12)))
                            .componentBackgroundOpacity()
                    }
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            }

            if #available(iOS 17.0, *)
            {
                Section(header: Text("新功能").appTextOpacity())
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
                                .background { Color.orange.componentBackgroundOpacity() }
                                .cornerRadius(6)

                            VStack(alignment: .leading, spacing: 2)
                            {
                                Text("查看新功能")
                                    .foregroundColor(.primary)
                                    .appTextOpacity()
                                Text("看看这次更新了什么")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .appTextOpacity()
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
            Section(header: Text("设置").appTextOpacity())
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
                    CurriculumDisplayScaleSettingView()
                } label: {
                    ProfileSettingRow(
                        title: "调整课表显示比例",
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
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        }
        .navigationTitle("我的")
        .navigationBarTitleDisplayMode(.inline)
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
        .onAppear
        {
            loadProfileBackgroundImage()
        }
        .onChange(of: backgroundImageFilename)
        { _ in
            loadProfileBackgroundImage()
        }
    }

    private func loadProfileBackgroundImage()
    {
        backgroundImage = BackgroundImageStore.loadImage(named: backgroundImageFilename)
    }
}

/// “我的”页所有设置入口共用的图标样式。
///
