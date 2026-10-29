// 个性化设置入口。

import SwiftUI

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
