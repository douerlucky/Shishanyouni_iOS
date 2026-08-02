//
//  AIAssistantView.swift
//  shishanyouni
//
//  AI 智学助手（beta）：绩点分析 / 课程分析 / 自由对话。
//  接入大模型 API（用户自带 Key），参考 Zhitu 的智学 Agent 实现。
//

import SwiftUI

// MARK: - 对话消息

struct AIChatMessage: Identifiable
{
    let id = UUID()
    let role: String // "user" / "agent"
    let content: String
}

// MARK: - ViewModel

@MainActor
class AIAssistantViewModel: ObservableObject
{
    @Published var gpaResult = ""
    @Published var courseResult = ""
    @Published var isGPALoading = false
    @Published var isCourseLoading = false

    @Published var chatMessages: [AIChatMessage] = []
    @Published var isChatLoading = false

    @Published var gpaDataCount = 0
    @Published var courseDataCount = 0

    private var chatTask: Task<Void, Never>?

    var hasAPIKey: Bool { AIKeyStore.hasAPIKey }

    func refreshData(username: String)
    {
        gpaDataCount = AIAnalysis.collectGradeData(username: username).count
        courseDataCount = AIAnalysis.collectCourseData().count
    }

    // MARK: - 绩点分析

    func analyzeGPA(username: String) async
    {
        let semesters = AIAnalysis.collectGradeData(username: username)
        gpaDataCount = semesters.count
        guard !semesters.isEmpty else
        {
            gpaResult = ""
            return
        }

        isGPALoading = true
        gpaResult = ""

        do
        {
            let stream = try await AIService.sendMessageWithStatus(
                modelId: AIKeyStore.selectedModelID,
                apiKey: AIKeyStore.apiKey,
                messages: [ChatAPIMessage(role: "user", content: AIAnalysis.buildGPAAnalysisPrompt(semesters: semesters, username: username))],
                systemPrompt: "你是一名专业的大学学业规划助手，回答用中文。"
            )

            switch stream
            {
            case .success(let stream):
                for await chunk in stream
                {
                    gpaResult += chunk
                }
            case .failure(let code, let body):
                gpaResult = "请求失败（HTTP \(code)）：\(String(body.prefix(300)))"
            }
        }
        catch
        {
            gpaResult = error.localizedDescription
        }

        isGPALoading = false
    }

    // MARK: - 课程分析

    func analyzeCourses(username: String) async
    {
        let courses = AIAnalysis.collectCourseData()
        let semesters = AIAnalysis.collectGradeData(username: username)
        courseDataCount = courses.count
        guard !courses.isEmpty || !semesters.isEmpty else
        {
            courseResult = ""
            return
        }

        isCourseLoading = true
        courseResult = ""

        do
        {
            let stream = try await AIService.sendMessageWithStatus(
                modelId: AIKeyStore.selectedModelID,
                apiKey: AIKeyStore.apiKey,
                messages: [ChatAPIMessage(role: "user", content: AIAnalysis.buildCourseAnalysisPrompt(courses: courses, semesters: semesters, username: username))],
                systemPrompt: "你是一名专业的大学课程学习规划助手，回答用中文。"
            )

            switch stream
            {
            case .success(let stream):
                for await chunk in stream
                {
                    courseResult += chunk
                }
            case .failure(let code, let body):
                courseResult = "请求失败（HTTP \(code)）：\(String(body.prefix(300)))"
            }
        }
        catch
        {
            courseResult = error.localizedDescription
        }

        isCourseLoading = false
    }

    // MARK: - 自由对话

    func sendChat(_ text: String, username: String) async
    {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isChatLoading else { return }

        chatMessages.append(AIChatMessage(role: "user", content: trimmed))
        isChatLoading = true

        var history: [ChatAPIMessage] = chatMessages.map { ChatAPIMessage(role: $0.role == "agent" ? "assistant" : "user", content: $0.content) }
        history = Array(history.suffix(20))
        let systemPrompt = AIAnalysis.buildChatSystemPrompt(semesters: AIAnalysis.collectGradeData(username: username))

        chatTask = Task
        {
            do
            {
                let stream = try await AIService.sendMessageWithStatus(
                    modelId: AIKeyStore.selectedModelID,
                    apiKey: AIKeyStore.apiKey,
                    messages: history,
                    systemPrompt: systemPrompt
                )

                switch stream
                {
                case .success(let stream):
                    var buffer = ""
                    for await chunk in stream
                    {
                        buffer += chunk
                        updateLastAgentMessage(buffer)
                    }
                case .failure(let code, let body):
                    updateLastAgentMessage("请求失败（HTTP \(code)）：\(String(body.prefix(300)))")
                }
            }
            catch
            {
                updateLastAgentMessage(error.localizedDescription)
            }
            isChatLoading = false
        }
    }

    private func updateLastAgentMessage(_ content: String)
    {
        if let last = chatMessages.last, last.role == "agent"
        {
            chatMessages[chatMessages.count - 1] = AIChatMessage(role: "agent", content: content)
        }
        else
        {
            chatMessages.append(AIChatMessage(role: "agent", content: content))
        }
    }

    func cancelChat()
    {
        chatTask?.cancel()
        isChatLoading = false
    }
}

// MARK: - 主视图

struct AIAssistantView: View
{
    @EnvironmentObject var userinfo: userInfo
    @StateObject private var vm = AIAssistantViewModel()
    @State private var tab: AITab = .gpa
    @State private var showAPIKeySheet = false

    enum AITab: String, CaseIterable, Identifiable
    {
        case gpa = "绩点分析"
        case course = "课程分析"
        case chat = "自由对话"

        var id: String { rawValue }
    }

    var body: some View
    {
        VStack(spacing: 0)
        {
            headerBar
            tabPicker
            contentView
        }
        .navigationTitle("智学助手")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .background(Color(uiColor: .systemGroupedBackground))
        .sheet(isPresented: $showAPIKeySheet)
        {
            AIAPIKeySheet()
        }
        .onAppear
        {
            vm.refreshData(username: userinfo.username)
        }
    }

    // MARK: - 顶部栏

    private var headerBar: some View
    {
        HStack(spacing: 10)
        {
            VStack(alignment: .leading, spacing: 3)
            {
                Text("AI 智学助手（beta）")
                    .font(.system(size: 17, weight: .bold))
                Text(vm.hasAPIKey ? "已接入 \(AIKeyStore.selectedModel?.displayName ?? "")" : "未配置 API Key")
                    .font(.system(size: 12))
                    .foregroundColor(vm.hasAPIKey ? .green : .orange)
            }

            Spacer()

            Button
            {
                showAPIKeySheet = true
            } label:
            {
                Label(vm.hasAPIKey ? "更换 Key" : "配置 Key", systemImage: "key.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(vm.hasAPIKey ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .foregroundColor(vm.hasAPIKey ? .green : .orange)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var tabPicker: some View
    {
        Picker("功能", selection: $tab)
        {
            ForEach(AITab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - 内容区

    @ViewBuilder
    private var contentView: some View
    {
        switch tab
        {
        case .gpa: gpaView
        case .course: courseView
        case .chat: chatView
        }
    }

    private var gpaView: some View
    {
        AnalysisResultView(
            dataCount: vm.gpaDataCount,
            dataName: "成绩数据",
            missingHint: "暂未找到缓存成绩。请先到首页「成绩查询」中查询成绩，再回来使用绩点分析。",
            isLoading: vm.isGPALoading,
            result: vm.gpaResult,
            actionTitle: "开始绩点分析"
        )
        {
            Task { await vm.analyzeGPA(username: userinfo.username) }
        }
    }

    private var courseView: some View
    {
        AnalysisResultView(
            dataCount: vm.courseDataCount,
            dataName: "课表课程",
            missingHint: "暂未找到课表数据。请先到「课表」页获取课程，再回来使用课程分析。",
            isLoading: vm.isCourseLoading,
            result: vm.courseResult,
            actionTitle: "开始课程分析"
        )
        {
            Task { await vm.analyzeCourses(username: userinfo.username) }
        }
    }

    private var chatView: some View
    {
        AIChatView(vm: vm, username: userinfo.username)
    }
}

// MARK: - 分析结果通用容器

private struct AnalysisResultView: View
{
    let dataCount: Int
    let dataName: String
    let missingHint: String
    let isLoading: Bool
    let result: String
    let actionTitle: String
    let action: () -> Void

    var body: some View
    {
        ScrollView
        {
            VStack(alignment: .leading, spacing: 16)
            {
                if dataCount > 0
                {
                    Text("已读取 \(dataCount) 条\(dataName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if result.isEmpty && !isLoading
                {
                    if dataCount == 0
                    {
                        VStack(spacing: 12)
                        {
                            Image(systemName: "tray")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary)
                            Text(missingHint)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                    else
                    {
                        Button(action: action)
                        {
                            Label(actionTitle, systemImage: "sparkles")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                }
                else if isLoading
                {
                    VStack(spacing: 12)
                    {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("AI 正在分析...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)

                    if !result.isEmpty
                    {
                        resultText
                    }
                }
                else
                {
                    resultText

                    Button("重新分析")
                    {
                        action()
                    }
                    .font(.subheadline)
                }
            }
            .padding()
        }
    }

    private var resultText: some View
    {
        Text(result)
            .font(.system(size: 15))
            .lineSpacing(5)
            .textSelection(.enabled)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
    }
}

// MARK: - 对话视图

private struct AIChatView: View
{
    @ObservedObject var vm: AIAssistantViewModel
    let username: String

    @State private var input = ""
    @FocusState private var inputFocused: Bool

    var body: some View
    {
        VStack(spacing: 0)
        {
            ScrollViewReader
            { proxy in
                ScrollView
                {
                    VStack(alignment: .leading, spacing: 12)
                    {
                        if vm.chatMessages.isEmpty
                        {
                            VStack(spacing: 10)
                            {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 36))
                                    .foregroundColor(.blue)
                                Text("可以问我：\n• 我的绩点怎么样？怎么提升？\n• 这几门课怎么安排学习？\n• 帮我制定期末复习计划")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 50)
                        }
                        else
                        {
                            ForEach(vm.chatMessages)
                            { message in
                                AIChatBubble(message: message)
                            }
                        }

                        if vm.isChatLoading
                        {
                            HStack(spacing: 6)
                            {
                                ProgressView()
                                Text("思考中...")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 12)
                        }
                    }
                    .padding()
                }
                .onChange(of: vm.chatMessages.count)
                { _ in
                    if let last = vm.chatMessages.last
                    {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            inputBar
        }
    }

    private var inputBar: some View
    {
        HStack(spacing: 10)
        {
            TextField("输入你的问题...", text: $input, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
                .focused($inputFocused)

            Button
            {
                let text = input
                input = ""
                Task { await vm.sendChat(text, username: username) }
            } label:
            {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(vm.isChatLoading ? .gray : .blue)
            }
            .disabled(vm.isChatLoading)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(uiColor: .systemBackground))
    }
}

private struct AIChatBubble: View
{
    let message: AIChatMessage

    var isUser: Bool { message.role == "user" }

    var body: some View
    {
        HStack
        {
            if isUser { Spacer(minLength: 40) }

            Text(message.content)
                .font(.system(size: 15))
                .lineSpacing(4)
                .textSelection(.enabled)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isUser ? Color.blue : Color(uiColor: .secondarySystemGroupedBackground))
                )
                .foregroundColor(isUser ? .white : .primary)

            if !isUser { Spacer(minLength: 40) }
        }
    }
}

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
                        ForEach(AIService.availableModels, id: \.id)
                        { model in
                            Text(model.displayName).tag(model.id)
                        }
                    }

                    ForEach(AIService.availableModels.filter { $0.id == selectedModelID }, id: \.id)
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

#Preview
{
    NavigationStack
    {
        AIAssistantView()
            .environmentObject(userInfo())
    }
}
