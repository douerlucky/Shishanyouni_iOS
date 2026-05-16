//
//  LoginView.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/9.
//

import SwiftUI
import UIKit

private enum LoginBindingSource: String, CaseIterable, Identifiable
{
    case shishanyouni
    case cas

    var id: String { rawValue }

    var title: String
    {
        switch self
        {
        case .shishanyouni:
            return "狮山有你服务器"
        case .cas:
            return "CAS"
        }
    }
}

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
    @State private var mfaFromShishanyouni = false
    @State private var shishanyouniMFASessionId: String?
    @State private var mfaSendCodeAction: (() async -> String?)?
    @AppStorage("login_binding_source") private var bindingSourceRawValue = LoginBindingSource.shishanyouni.rawValue

    private var bindingSource: LoginBindingSource
    {
        get { LoginBindingSource(rawValue: bindingSourceRawValue) ?? .shishanyouni }
        nonmutating set { bindingSourceRawValue = newValue.rawValue }
    }

    private var isRunningInPreview: Bool
    {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    var casBinder: CASBinder = CASBinder()

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
                    Picker("绑定方式", selection: Binding(
                        get: { bindingSource },
                        set: { bindingSource = $0 }
                    ))
                    {
                        ForEach(LoginBindingSource.allCases)
                        { source in
                            Text(source.title)
                                .tag(source)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 2)

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
                        loginInputField(
                            placeholder: "请输入学号",
                            text: $username,
                            isSecure: false,
                            keyboardType: .numberPad
                        )
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
                        loginInputField(
                            placeholder: "请输入密码",
                            text: $password,
                            isSecure: true,
                            keyboardType: .default
                        )
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
                            if TestAccount.matches(username: username, password: password)
                            {
                                completeTestAccountBinding()
                                return
                            }

                            let selectedSource = bindingSource
                            let schoolPassword = encryptSchoolPassword(password: password)
                            let shishanyouniPassword = encryptShishanyouniPassword(password: password)
                            let bindingResult: (Bool, String?)

                            switch selectedSource
                            {
                            case .shishanyouni:
                                guard let shishanyouniPassword else
                                {
                                    await MainActor.run
                                    {
                                        self.alertTitle = "出现错误"
                                        self.alertMessage = "狮山有你后端密码加密失败，请稍后重试或联系开发者检查公钥配置。"
                                        self.showAlert = true
                                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                                    }
                                    return
                                }
                                bindingResult = await performShishanyouniBinding(username: username, encryptedPassword: shishanyouniPassword)
                            case .cas:
                                guard let schoolPassword else
                                {
                                    await MainActor.run
                                    {
                                        self.alertTitle = "出现错误"
                                        self.alertMessage = "CAS 密码加密失败，请稍后重试或联系开发者检查公钥配置。"
                                        self.showAlert = true
                                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                                    }
                                    return
                                }
                                bindingResult = await performCASBinding(username: username, encryptedPassword: schoolPassword)
                            }

                            let isBound = bindingResult.0

                            await MainActor.run
                            {
                                if isBound
                                {
                                    userinfo.username = username
                                    userinfo.plainPassword = password
                                    if let schoolPassword
                                    {
                                        userinfo.encryptedPasswordSchool = schoolPassword
                                    }
                                    if let shishanyouniPassword
                                    {
                                        userinfo.encryptedPasswordShishanyouni = shishanyouniPassword
                                    }

                                    switch selectedSource
                                    {
                                    case .shishanyouni:
                                        userinfo.updateBindingStatus(casBound: userinfo.isCASBound, shishanyouniBound: true)
                                    case .cas:
                                        userinfo.updateBindingStatus(casBound: true, shishanyouniBound: userinfo.isShishanyouniBound)
                                    }
                                }
                                refreshBindingStatusText()

                                if isBound
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

                                let alert = buildSingleBindingAlert(
                                    source: selectedSource,
                                    isBound: isBound,
                                    message: bindingResult.1
                                )

                                self.alertTitle = alert.0
                                self.alertMessage = alert.1
                                self.showAlert = true

                                if isBound
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
                    bindingIndicator(title: "狮山有你后端连接", isBound: userinfo.isShishanyouniBound, message: backendStatusMessage)
                    bindingIndicator(title: "CAS 连接", isBound: userinfo.isCASBound, message: casStatusMessage)
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

                    Text("正在绑定\n\(bindingSource.title)")
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
                fromShishanyouni: mfaFromShishanyouni,
                onSendCode: $mfaSendCodeAction,
                onCancel: { resolveMFACode(nil) },
                onConfirm: { resolveMFACode(mfaCode.trimmingCharacters(in: .whitespacesAndNewlines)) }
            )
        }
    }
}

extension LoginView {
    @ViewBuilder
    private func loginInputField(
        placeholder: String,
        text: Binding<String>,
        isSecure: Bool,
        keyboardType: UIKeyboardType
    ) -> some View
    {
        if isRunningInPreview
        {
            CanvasLoginTextField(
                text: text,
                placeholder: placeholder,
                isSecure: isSecure,
                keyboardType: keyboardType == .numberPad ? .default : keyboardType
            )
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(Color(.systemGray6))
            .clipShape(Capsule())
        }
        else if isSecure
        {
            SecureField(placeholder, text: text)
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        else
        {
            TextField(placeholder, text: text)
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
                .keyboardType(keyboardType)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
    }

    @MainActor
    private func completeTestAccountBinding()
    {
        TestAccount.apply(to: userinfo)
        refreshBindingStatusText()

        if rememberPassword
        {
            userinfo.saveUserInfo()
        }
        else
        {
            userinfo.clearSavedCredentials()
        }

        let alert = buildBindingAlerts(
            casBound: true,
            casMessage: nil,
            backendBound: true,
            backendMessage: nil
        )
        alertTitle = alert.0
        alertMessage = alert.1
        showAlert = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func performCASBinding(username: String, encryptedPassword: String) async -> (Bool, String?) {
        do
        {
            let result = try await casBinder.bind(
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

    private func performShishanyouniBinding(username: String, encryptedPassword: String) async -> (Bool, String?) {
        do
        {
            let binder = ShishanyouniBinder()
            try await binder.bind(username: username, password: encryptedPassword)
            return (true, nil)
        }
        catch ShishanyouniAPIError.needMFA(let phone, let sessionId, let message)
        {
            do
            {
                let binder = ShishanyouniBinder()
                guard let smsCode = await requestShishanyouniMFACode(maskedPhone: phone, sessionId: sessionId),
                      !smsCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else
                {
                    return (false, "已取消短信验证码验证。")
                }

                let token = try await binder.submitCode(sessionId: sessionId, smsCode: smsCode)
                await MainActor.run
                {
                    userinfo.updateShishanyouniToken(token)
                    shishanyouniMFASessionId = nil
                }
                return (true, message)
            }
            catch
            {
                return (false, error.localizedDescription)
            }
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

    private func buildSingleBindingAlert(source: LoginBindingSource, isBound: Bool, message: String?) -> (String, String) {
        if isBound
        {
            return ("绑定成功", "\(source.title) 已绑定成功。")
        }
        return ("绑定失败", "绑定 \(source.title) 有问题：\(message ?? "请稍后重试。")")
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
        mfaFromShishanyouni = false
        shishanyouniMFASessionId = nil
        mfaSendCodeAction = MFACodeContext.activeSendCodeAction
        await Task.yield()
        showMFASheet = true
        return await withCheckedContinuation { continuation in
            mfaContinuation = continuation
        }
    }

    @MainActor
    private func requestShishanyouniMFACode(maskedPhone: String, sessionId: String) async -> String? {
        mfaMaskedPhone = maskedPhone
        mfaCode = ""
        mfaFromShishanyouni = true
        shishanyouniMFASessionId = sessionId
        mfaSendCodeAction = { await sendShishanyouniMFACode() }
        await Task.yield()
        showMFASheet = true
        return await withCheckedContinuation { continuation in
            mfaContinuation = continuation
        }
    }

    private func sendShishanyouniMFACode() async -> String? {
        guard let sessionId = await MainActor.run(body: { shishanyouniMFASessionId }) else
        {
            return "短信验证会话已失效，请重新绑定。"
        }

        do
        {
            try await ShishanyouniBinder().sendCode(sessionId: sessionId)
            return nil
        }
        catch
        {
            return error.localizedDescription
        }
    }

    @MainActor
    private func resolveMFACode(_ code: String?) {
        showMFASheet = false
        mfaContinuation?.resume(returning: code)
        mfaContinuation = nil
        mfaSendCodeAction = nil
        if code == nil
        {
            shishanyouniMFASessionId = nil
        }
    }
}

private struct CanvasLoginTextField: UIViewRepresentable
{
    @Binding var text: String
    let placeholder: String
    let isSecure: Bool
    let keyboardType: UIKeyboardType

    func makeUIView(context: Context) -> UITextField
    {
        let textField = UITextField(frame: .zero)
        textField.placeholder = placeholder
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.keyboardType = keyboardType
        textField.isSecureTextEntry = isSecure
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.textContentType = isSecure ? .password : .username
        textField.delegate = context.coordinator
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textDidChange(_:)),
            for: .editingChanged
        )
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context)
    {
        if uiView.text != text
        {
            uiView.text = text
        }
        uiView.placeholder = placeholder
        uiView.keyboardType = keyboardType
        uiView.isSecureTextEntry = isSecure
    }

    func makeCoordinator() -> Coordinator
    {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, UITextFieldDelegate
    {
        private var text: Binding<String>

        init(text: Binding<String>)
        {
            self.text = text
        }

        @objc func textDidChange(_ sender: UITextField)
        {
            text.wrappedValue = sender.text ?? ""
        }
    }
}

#Preview
{
    LoginView()
        .environmentObject(userInfo())
}
