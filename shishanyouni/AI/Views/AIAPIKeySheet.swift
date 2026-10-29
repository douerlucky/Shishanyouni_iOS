import SwiftUI

// MARK: - API Key 配置

struct AIAPIKeySheet: View
{
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var selectedModelID = AIKeyStore.selectedModelID
    @State private var testResult: String?
    @State private var isTesting = false

    var body: some View
    {
        NavigationStack
        {
            Form
            {
                Section
                {
                    SecureField("API Key", text: $key)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Picker("模型", selection: $selectedModelID)
                    {
                        ForEach(AIAPI.availableModels, id: \.id)
                        { model in
                            Text(model.displayName).tag(model.id)
                        }
                    }

                    ForEach(AIAPI.availableModels.filter { $0.id == selectedModelID }, id: \.id)
                    { model in
                        Text(model.description)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                } header:
                {
                    Text("大模型 API")
                } footer:
                {
                    Text("Key 仅保存在本机钥匙串中，用于直接调用模型 API，不会上传到任何服务器。可在 DeepSeek / 通义千问 / 智谱等平台申请。")
                }

                if let testResult
                {
                    Section
                    {
                        Text(testResult)
                            .font(.footnote)
                            .foregroundColor(testResult.hasPrefix("连接成功") ? .green : .red)
                    }
                }
            }
            .navigationTitle("智学助手设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar
            {
                ToolbarItem(placement: .cancellationAction)
                {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction)
                {
                    Button("保存")
                    {
                        AIKeyStore.saveAPIKey(key)
                        AIKeyStore.selectedModelID = selectedModelID
                        dismiss()
                    }
                }
                ToolbarItem(placement: .bottomBar)
                {
                    Button
                    {
                        isTesting = true
                        testResult = nil
                        Task
                        {
                            AIKeyStore.saveAPIKey(key)
                            AIKeyStore.selectedModelID = selectedModelID
                            let result = await AIKeyStore.testConnection()
                            testResult = result
                            isTesting = false
                        }
                    } label:
                    {
                        if isTesting
                        {
                            HStack(spacing: 6)
                            {
                                ProgressView()
                                Text("测试中...")
                            }
                        }
                        else
                        {
                            Text("测试连接")
                        }
                    }
                    .disabled(isTesting || key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear
            {
                key = AIKeyStore.apiKey
            }
        }
    }
}
