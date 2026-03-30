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
    @State private var showNicknameAlert = false
    @State private var tempNickname = "" // 弹窗临时的输入

    var greeting: String
    {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour
        {
        case 0 ..< 5: return "凌晨好, 还在卷吗"
        case 5 ..< 9: return "早上好"
        case 9 ..< 11: return "上午好"
        case 11 ..< 13: return "中午好"
        case 13 ..< 18: return "下午好"
        case 18 ..< 24: return "晚上好"
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
                    Text("点击下方账号设置进行登录")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
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
                            Text("学号")
                                .font(.body)
                            if userinfo.username.isEmpty
                            {
                                Text("未登录")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            else
                            {
                                Text(userinfo.username)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }

            // 第二组：设置
            Section(header: Text("账号设置"))
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

                Toggle(isOn: $userinfo.showDailyMessage)
                {
                    HStack(spacing: 12)
                    { // 保持跟上面一样的间距
                        // 左侧图标胶囊
                        Image(systemName: "quote.bubble.fill")
                            .foregroundColor(.white) // 图标颜色
                            .frame(width: 30, height: 30) // 胶囊尺寸
                            .background(Color.orange) // 寄语用醒目的橙色
                            .cornerRadius(6) // 圆角

                        Text("显示今日寄语")
                            .foregroundColor(.primary)
                    }
                }
                .tint(.accentColor) // 右侧开关的颜色

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
                            .font(.footnote) // 这个图标比较复杂，稍微缩小一点点字号
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.green) // 天数用充满希望的绿色
                            .cornerRadius(6)

                        Text("显示入校天数")
                            .foregroundColor(.primary)
                    }
                }
                .tint(.accentColor)

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
    }
}

#Preview
{
    ProfileView()
        .environmentObject(userInfo())
}
