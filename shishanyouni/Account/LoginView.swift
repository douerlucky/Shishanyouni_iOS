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
    @State private var casStatusMessage = "未绑定"
    @State private var backendStatusMessage = "未绑定"
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
                            guard let schoolPassword = encryptSchoolPassword(password: password) else {
                                await MainActor.run {
                                    self.alertTitle = "出现错误"
                                    self.alertMessage = "CAS 密码加密失败，请稍后重试或联系开发者检查公钥配置。"
                                    self.showAlert = true
                                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                                }
                                return
                            }
                            guard let shishanyouniPassword = encryptShishanyouniPassword(password: password) else {
                                await MainActor.run {
                                    self.alertTitle = "出现错误"
                                    self.alertMessage = "狮山有你后端密码加密失败，请稍后重试或联系开发者检查公钥配置。"
                                    self.showAlert = true
                                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                                }
                                return
                            }

                            async let casAttempt = performCASBinding(username: username, encryptedPassword: schoolPassword)
                            async let backendAttempt = performBackendBinding(username: username, encryptedPassword: shishanyouniPassword)
                            let (casResult, backendResult) = await (casAttempt, backendAttempt)
                            let casBound = casResult.0
                            let backendBound = backendResult.0

                            await MainActor.run
                            {
                                if casBound || backendBound
                                {
                                    userinfo.username = username
                                    userinfo.plainPassword = password
                                    userinfo.encryptedPasswordSchool = schoolPassword
                                    userinfo.encryptedPasswordShishanyouni = shishanyouniPassword
                                }
                                userinfo.updateBindingStatus(casBound: casBound, shishanyouniBound: backendBound)
                                refreshBindingStatusText()

                                if casBound || backendBound
                                {
                                    if rememberPassword
                                    {
                                        userinfo.saveUserInfo()
                                    }
                                    else
                                    {
                                        userinfo.clearSavedCredentials()
                                    }
                                }

                                let alert = buildBindingAlerts(
                                    casBound: casBound,
                                    casMessage: casResult.1,
                                    backendBound: backendBound,
                                    backendMessage: backendResult.1
                                )

                                self.alertTitle = alert.0
                                self.alertMessage = alert.1
                                self.showAlert = true

                                if casBound || backendBound
                                {
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                }
                                else
                                {
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

                VStack(spacing: 12)
                {
                    bindingIndicator(title: "CAS 连接", isBound: userinfo.isCASBound, message: casStatusMessage)
                    bindingIndicator(title: "狮山有你后端连接", isBound: userinfo.isShishanyouniBound, message: backendStatusMessage)
                }
                .padding(.horizontal, 20)

                if !userinfo.username.isEmpty
                {
                    Button(role: .destructive)
                    {
                        showLogoutConfirm = true
                    } label: {
                        HStack
                        {
                            Image(systemName: "person.badge.minus")
                            Text("退出登录")
                        }
                        .font(.footnote)
                    }
                    .padding(.top, 8)
                    .confirmationDialog("确定要退出当前登录状态吗？", isPresented: $showLogoutConfirm, titleVisibility: .visible)
                    {
                        Button("退出登录", role: .destructive)
                        {
                            userinfo.clearUserInfo()
                            username = ""
                            password = ""
                            refreshBindingStatusText()
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

                    Text("正在绑定CAS与\n狮山有你")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
    
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
            refreshBindingStatusText()
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
    private func performCASBinding(username: String, encryptedPassword: String) async -> (Bool, String?) {
        do
        {
            let result = try await loginChecker.checkLogin(
                username: username,
                password: encryptedPassword,
                mfaCodeProvider: { phone in
                    await requestMFACode(maskedPhone: phone)
                }
            )
            switch result
            {
            case .success:
                return (true, nil)
            case let .failure(message):
                return (false, message)
            }
        }
        catch
        {
            return (false, error.localizedDescription)
        }
    }

    private func performBackendBinding(username: String, encryptedPassword: String) async -> (Bool, String?) {
        do
        {
            try await AccountBinder().bind(username: username, password: encryptedPassword)
            return (true, nil)
        }
        catch
        {
            return (false, error.localizedDescription)
        }
    }

    private func buildBindingAlerts(casBound: Bool, casMessage: String?, backendBound: Bool, backendMessage: String?) -> (String, String) {
        var messages: [String] = []
        if casBound {
            messages.append("CAS 已绑定成功。")
        } else {
            messages.append("绑定 CAS 服务有问题：\(casMessage ?? "请稍后重试。")")
        }

        if backendBound {
            messages.append("狮山有你后端已绑定成功。")
        } else {
            messages.append("绑定狮山有你后端有问题：\(backendMessage ?? "请稍后重试。")")
        }

        return ("绑定结果", messages.joined(separator: "\n"))
    }

    @MainActor
    private func refreshBindingStatusText() {
        casStatusMessage = userinfo.isCASBound ? "已绑定" : "未绑定"
        backendStatusMessage = userinfo.isShishanyouniBound ? "已绑定" : "未绑定"
    }

    @ViewBuilder
    private func bindingIndicator(title: String, isBound: Bool, message: String) -> some View {
        HStack(spacing: 12)
        {
            Circle()
                .fill(isBound ? Color.green : Color.red)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2)
            {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

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
