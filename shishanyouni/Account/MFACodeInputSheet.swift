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
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("检测到本次登录需要安全验证。")
                    .font(.headline)
                Text(maskedPhone.isEmpty ? "请输入短信验证码" : "已向 \(maskedPhone) 发送验证码，请输入")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField("短信验证码", text: $code)
                    .keyboardType(.numberPad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

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
        .presentationDetents([.height(250)])
        .interactiveDismissDisabled()
    }
}
