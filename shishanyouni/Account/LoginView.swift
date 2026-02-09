//
//  LoginView.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/9.
//

import SwiftUI

struct LoginView: View
{
    @EnvironmentObject var userinfo: userInfo

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var rememberPassword: Bool = true
    @State private var isLoading: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertTitle = ""
    @State private var alertMessage: String = ""
    @State private var showLogoutConfirm: Bool = false

    var loginChecker: LoginChecker = LoginChecker()

    var body: some View
    {
        ZStack
        {
            VStack(spacing: 16)
            {
                Text("使用信息门户的学号和密码来进行登录")

                VStack(spacing: 16)
                {
                    // 学号行
                    HStack(spacing: 8)
                    {
                        // 左边：学号标签胶囊
                        HStack
                        {
                            Image(systemName: "person.fill")
                            Text("学号")
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                        .frame(width: 90, height: 44)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())

                        // 右边：学号输入胶囊
                        TextField("请输入学号", text: $username)
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                            .background(Color(.systemGray6))
                            .clipShape(Capsule())
                            .keyboardType(.numberPad)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }

                    // 密码行
                    HStack(spacing: 8)
                    {
                        // 左边：密码标签胶囊
                        HStack
                        {
                            Image(systemName: "lock.fill")
                            Text("密码")
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                        .frame(width: 90, height: 44)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())

                        // 右边：密码输入胶囊
                        SecureField("请输入密码", text: $password)
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                            .background(Color(.systemGray6))
                            .clipShape(Capsule())
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                }
                .padding(.horizontal, 20)

                Toggle("记住密码", isOn: $rememberPassword)
                    .frame(width: 150)
                    .padding(.top, 8)

                Button("登录")
                {
                    if username.isEmpty
                    {
                        self.alertTitle = "你太不小心了"
                        self.alertMessage = "怎么会忘了填学号呢？"
                        self.showAlert = true
                    }
                    else if password.isEmpty
                    {
                        self.alertTitle = "你太不小心了"
                        self.alertMessage = "怎么会忘了填密码呢？"
                        self.showAlert = true
                    }
                    else
                    {
                        isLoading = true

                        Task
                        {
                            defer { isLoading = false }
                            let cryptPassword = encryptPassword(password: password)
                            do
                            {
                                let result_status = try await loginChecker.checkLogin(username: username, password: cryptPassword!)
                                print(result_status)
                                switch result_status
                                {
                                case .success:
                                    await MainActor.run
                                    {
                                        // 成功弹窗
                                        self.alertTitle = "登录成功"
                                        self.alertMessage = "可以正常使用啦"
                                        self.showAlert = true

                                        if rememberPassword
                                        {
                                            userinfo.username = username
                                            userinfo.plainPassword = password
                                            userinfo.performEncryption()
                                            userinfo.saveUserInfo()
                                        }
                                        else
                                        {
                                            userinfo.clearUserInfo()
                                        }
                                    }

                                case let .failure(reason):
                                    print("登录失败，原因是：\(reason)")
                                    await MainActor.run
                                    {
                                        // 失败
                                        self.alertTitle = "出现错误"
                                        self.alertMessage = "用户名或密码有错误"
                                        self.showAlert = true
                                    }
                                }
                            }
                            catch
                            {
                                print("查询失败")
                            }
                        }
                    }
                }
                .buttonStyle(.automatic)
                .padding()
                .foregroundColor(.white)
                .background(Color(.systemBlue))
                .clipShape(Capsule())

                if !userinfo.username.isEmpty
                {
                    Button(role: .destructive)
                    {
                        showLogoutConfirm = true
                    } label: {
                        HStack
                        {
                            Image(systemName: "person.badge.minus")
                            Text("清除保存并退出")
                        }
                        .font(.footnote)
                    }
                    .padding(.top, 8)
                    .confirmationDialog("确定要清除保存的登录信息吗？", isPresented: $showLogoutConfirm, titleVisibility: .visible)
                    {
                        Button("清除并退出", role: .destructive)
                        {
                            userinfo.clearUserInfo()
                            username = ""
                            password = ""
                        }
                        Button("取消", role: .cancel) { }
                    }
                }
            }
            .blur(radius: isLoading ? 3 : 0)

            // 加载提示 - 居中显示
            if isLoading
            {
                VStack(spacing: 15)
                {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.blue)

                    Text("正在尝试登录")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(width: 180, height: 120)
                .background(Color(.systemBackground).opacity(0.95))
                .cornerRadius(15)
                .shadow(radius: 10)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .onAppear
        {
            // 自动填充保存的学号和密码
            if !userinfo.username.isEmpty
            {
                username = userinfo.username
                password = userinfo.plainPassword
                rememberPassword = true
            }
        }
        .alert(alertTitle, isPresented: $showAlert)
        {
            Button("确定", role: .cancel)
            {
                // 如果登录成功，可以在这里进行跳转
                if alertTitle == "登录成功"
                {
                    // 执行登录成功后的操作
                }
            }
        } message: {
            if !alertMessage.isEmpty
            {
                Text(alertMessage)
            }
        }
    }
}

#Preview
{
    LoginView()
        .environmentObject(userInfo())
}
