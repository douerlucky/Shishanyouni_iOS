//
//  MFACodeInputSheet.swift
//  shishanyouni
//
//  Created by Codex on 2026/4/23.
//

import SwiftUI

struct MFACodeInputSheet: View {
    let maskedPhone: String
    @Binding var code: String
    var fromShishanyouni: Bool = false
    @Binding var onSendCode: (() async -> String?)?
    let onCancel: () -> Void
    let onConfirm: () -> Void
    @State private var isSendingCode = false
    @State private var sendMessage: String?
    @State private var countdown = 0
    @State private var countdownTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("检测到本次登录需要安全验证。")
                    .font(.headline)
                Text(descriptionText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 10)
                {
                    TextField("短信验证码", text: $code)
                        .keyboardType(.numberPad)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button
                    {
                        Task { await sendCode() }
                    } label: {
                        HStack(spacing: 6)
                        {
                            if isSendingCode
                            {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(sendButtonTitle)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .frame(width: 118, height: 44)
                        .background(Color.blue.opacity((isSendingCode || countdown > 0) ? 0.12 : 0.22))
                        .foregroundColor(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSendingCode || countdown > 0)
                }

                if let sendMessage
                {
                    Text(sendMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("安全手机验证")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定", action: onConfirm)
                        .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.height(280)])
        .interactiveDismissDisabled()
        .onDisappear
        {
            countdownTask?.cancel()
            countdownTask = nil
        }
    }

    private var descriptionText: String
    {
        maskedPhone.isEmpty ? "请点击获取验证码，再输入短信验证码" : "将向 \(maskedPhone) 发送验证码，请点击获取"
    }

    private var sendButtonTitle: String
    {
        if countdown > 0
        {
            return "\(countdown)s"
        }
        return "获取验证码"
    }

    @MainActor
    private func sendCode() async
    {
        let sendAction = onSendCode ?? MFACodeContext.activeSendCodeAction
        guard let sendAction else
        {
            sendMessage = "验证码发送通道还在准备，请稍后再试。"
            return
        }

        isSendingCode = true
        sendMessage = nil
        let message = await sendAction()
        isSendingCode = false
        sendMessage = message
        if message == nil
        {
            startCountdown()
        }
    }

    @MainActor
    private func startCountdown()
    {
        countdownTask?.cancel()
        countdown = 120
        countdownTask = Task
        {
            while !Task.isCancelled && countdown > 0
            {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run
                {
                    countdown -= 1
                }
            }
        }
    }
}
