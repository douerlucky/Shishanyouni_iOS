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
    @Environment(\.dismiss) private var dismiss

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var rememberPassword: Bool = true
    @State private var isLoading: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertTitle = ""
    @State private var alertMessage: String = ""
    @State private var showLogoutConfirm: Bool = false
    @State private var showMFASheet = false
    @State private var mfaMaskedPhone = ""
    @State private var mfaCode = ""
    @State private var mfaContinuation: CheckedContinuation<String?, Never>?

    var loginChecker: LoginChecker = LoginChecker()

    var body: some View
    {
        ZStack
        {
            VStack(spacing: 32)
            {
                VStack(spacing:32)
                {
                    Image("login")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 128, height: 128)
                        .cornerRadius(32)
                    Text("绑定校园信息门户账号，即表示接受我们为你提供个性化校园服务。")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }


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
                


                Button
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
                            let cryptPassword = encryptSchoolPassword(password: password)
                            do
                            {
                                let result_status = try await loginChecker.checkLogin(
                                    username: username,
                                    password: cryptPassword!,
                                    mfaCodeProvider: { phone in
                                        await requestMFACode(maskedPhone: phone)
                                    }
                                )
                                print(result_status)
                                switch result_status
                                {
                                case .success:
                                    await MainActor.run
                                    {
                                        userinfo.username = username
                                        userinfo.plainPassword = password
                                        userinfo.performSchoolEncryption()
                                        userinfo.performShishanyouniEncryption()

                                        if rememberPassword
                                        {
                                            userinfo.saveUserInfo()
                                        }
                                        else
                                        {
                                            userinfo.clearSavedCredentials()
                                        }
                                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                                        dismiss()
                                    }
                                    
                                    Task {
                                            await AccountBinder().bind(username: username, password: password)
                                        }
                                    

                                case let .failure(reason):
                                    print("绑定失败，原因是：\(reason)")
                                    await MainActor.run
                                    {
                                        // 失败
                                        self.alertTitle = "出现错误"
                                        self.alertMessage = "用户名或密码有错误"
                                        self.showAlert = true
                                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                                    }
                                }
                            }
                            catch
                            {
                                await MainActor.run {
                                    self.alertTitle = "出现错误"
                                    self.alertMessage = error.localizedDescription
                                    self.showAlert = true
                                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                                }
                            }
                        }
                    }
                }
            label:
                {
                    Text("绑定")
                            .fontWeight(.bold)
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .frame(maxWidth: 300)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .clipShape(Capsule())
                }
                .optionalLiquidGlass()
                .padding()
                

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
                    .confirmationDialog("确定要清除保存的绑定信息吗？", isPresented: $showLogoutConfirm, titleVisibility: .visible)
                    {
                        Button("清除并退出", role: .destructive)
                        {
                            userinfo.clearUserInfo()
                            username = ""
                            password = ""
                            dismiss()
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

                    Text("正在尝试绑定信息门户账号")
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
            }
        } message: {
            if !alertMessage.isEmpty
            {
                Text(alertMessage)
            }
        }
        .sheet(isPresented: $showMFASheet) {
            MFACodeInputSheet(
                maskedPhone: mfaMaskedPhone,
                code: $mfaCode,
                onCancel: { resolveMFACode(nil) },
                onConfirm: { resolveMFACode(mfaCode.trimmingCharacters(in: .whitespacesAndNewlines)) }
            )
        }
    }
}

extension LoginView {
    @MainActor
    private func requestMFACode(maskedPhone: String?) async -> String? {
        mfaMaskedPhone = maskedPhone ?? ""
        mfaCode = ""
        showMFASheet = true
        return await withCheckedContinuation { continuation in
            mfaContinuation = continuation
        }
    }

    @MainActor
    private func resolveMFACode(_ code: String?) {
        showMFASheet = false
        mfaContinuation?.resume(returning: code)
        mfaContinuation = nil
    }
}

#Preview
{
    LoginView()
        .environmentObject(userInfo())
}
