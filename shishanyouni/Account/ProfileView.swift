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
    @State private var showNicknameAlert = false
    @State private var tempNickname = "" // 弹窗临时的输入
    @State private var navigateToSubscription = false
    @State private var showWhatsNew = false

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

            // 第二组：个性化设置
            Section(header: Text("个性化设置"))
            {
                Button(action: {
                    // 1. 先把当前的昵称同步给临时变量
                    tempNickname = userinfo.nickname
                    // 2. 触发弹窗
                    showNicknameAlert = true
                })
                {
                    HStack(spacing: 15)
                    {
                        // 左侧图标胶囊
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.gray)
                            .cornerRadius(6)

                        Text("昵称设置")
                            .foregroundColor(.primary) // 修正 Button 默认的蓝色

                        Spacer() // 顶满中间

                        // 右侧的小箭头（伪装 NavigationLink 的灵魂）
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundColor(Color(.systemGray3))
                    }
                }

                // 2. 显示日期与时钟
                Toggle(isOn: $userinfo.showClock)
                {
                    HStack(spacing: 12)
                    {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.blue) // 时钟用冷色调的蓝色
                            .cornerRadius(6)

                        Text("显示日期与时钟")
                            .foregroundColor(.primary)
                    }
                }
                .tint(.accentColor)

                // 3. 显示入校天数
                Toggle(isOn: $userinfo.showEnrollmentDays)
                {
                    HStack(spacing: 12)
                    {
                        Image(systemName: "calendar.badge.clock")
                            .font(.footnote)
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.green)
                            .cornerRadius(6)

                        Text("显示入校天数")
                            .foregroundColor(.primary)
                    }
                }
                .tint(.accentColor)

                // 4. 显示下一个安排
                Toggle(isOn: $userinfo.showNextEvent)
                {
                    HStack(spacing: 12)
                    {
                        Image(systemName: "rectangle.and.text.magnifyingglass")
                            .font(.footnote)
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.blue)
                            .cornerRadius(6)

                        Text("显示下一个安排")
                            .foregroundColor(.primary)
                    }
                }
                .tint(.accentColor)

                // 5. 背景图片设置
                NavigationLink {
                    BackgroundSettingView()
                } label: {
                    HStack(spacing: 15)
                    {
                        Image(systemName: "photo.on.rectangle.angled")
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.blue)
                            .cornerRadius(6)
                        Text("背景图片设置")
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }

                // 6. 默认启动页面
                Picker(selection: $userinfo.defaultTab) {
                    Text("日程").tag(0)
                    Text("课表").tag(1)
                    Text("首页").tag(2)
                } label: {
                    HStack(spacing: 12)
                    {
                        Image(systemName: "house.and.flag.fill")
                            .font(.footnote)
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.purple)
                            .cornerRadius(6)

                        Text("默认启动页面")
                            .foregroundColor(.primary)
                    }
                }

                NavigationLink
                {
                    AboutUs()
                } label: {
                    HStack(spacing: 15)
                    {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.green)
                            .cornerRadius(6)
                        Text("关于狮山有你iOS")
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
            }
            .alert("个性化设置", isPresented: $showNicknameAlert)
            {
                TextField("输入你的昵称", text: $tempNickname)
                    .textInputAutocapitalization(.never)

                Button("取消", role: .cancel) { }
                Button("确定")
                {
                    userinfo.nickname = tempNickname // 同步回全局变量
                    userinfo.saveUserInfo()
                }
            } message: {
                Text("请输入你想使用的昵称")
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

#Preview
{
    ProfileView()
        .environmentObject(userInfo())
        .environmentObject(IAPStore.preview(hasActiveSubscription: false))
}
