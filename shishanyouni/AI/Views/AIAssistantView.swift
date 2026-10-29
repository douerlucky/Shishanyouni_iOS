import SwiftUI

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
            }
            .nativeGlassButtonStyle()
            .tint(vm.hasAPIKey ? .green : .orange)
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
