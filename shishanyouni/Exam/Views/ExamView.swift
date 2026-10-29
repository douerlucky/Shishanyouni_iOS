import Combine
import EventKit
import SwiftUI

private let queryTimestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    return formatter
}()

struct ExamView: View
{
    @EnvironmentObject var userinfo: userInfo
    @State var exams: [Exam] = []
    @State private var isLoading = false

    // 弹窗状态
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var errorRetryAction: (() -> Void)?
    @State private var showMFASheet = false
    @State private var mfaMaskedPhone = ""
    @State private var mfaCode = ""
    @State private var mfaContinuation: CheckedContinuation<String?, Never>?
    @State private var mfaSendCodeAction: (() async -> String?)?

    @State var selectedYear: String
    @State var selectedTerm: String
    @AppStorage("examQuerySource") private var querySourceRaw = ExamQuerySource.cas.rawValue

    private var querySource: ExamQuerySource
    {
        get { ExamQuerySource(rawValue: querySourceRaw) ?? .cas }
        nonmutating set { querySourceRaw = newValue.rawValue }
    }

    // 声明查询工具
    private let scheduleQuery = SchoolAcademicAPI()
    @StateObject private var backendMFA = ShishanyouniMFAPresenter()
    private let examQuery = ExamAPI.shared

    init()
    {
        let semester = AcademicQuerySemester.forDate(Date())
        _selectedYear = State(initialValue: semester.year)
        _selectedTerm = State(initialValue: semester.term)
    }

    private var lastQueryText: String?
    {
        guard !userinfo.username.isEmpty,
              let date = ExamStore.shared.lastUpdatedAt(
                username: userinfo.username,
                year: selectedYear,
                term: selectedTerm,
                source: querySource
              ) else { return nil }
        return "上次查询：\(queryTimestampFormatter.string(from: date))"
    }

    var body: some View
    {
        ZStack(alignment: .bottom)
        {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            // 底层的考试列表
            ZStack
            {
                if exams.isEmpty
                {
                    VStack(spacing: 10)
                    {
                        if let lastQueryText
                        {
                            Text(lastQueryText)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        Spacer()
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary.opacity(0.6))
                            .padding(.bottom, 8)
                        Text("未查询到任何考试安排")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .blur(radius: isLoading ? 3 : 0)
                }
                else
                {
                    List
                    {
                        if let lastQueryText
                        {
                            Text(lastQueryText)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }

                        ForEach(exams) { item in
                            ExamCard(exam: item)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .blur(radius: isLoading ? 3 : 0)
                    .safeAreaInset(edge: .bottom)
                    {
                        Color.clear.frame(height: 100)
                    }
                }

                if isLoading
                {
                    VStack(spacing: 12)
                    {
                        ProgressView()
                            .tint(.blue)
                        Text("正在努力加载考试信息...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(25)
                    .background(Color(.systemBackground).opacity(0.8))
                    .cornerRadius(15)
                    .shadow(radius: 5)
                }
            }

            // 浮动按钮区域 - 严格仿照 GradeView 的 UI 格式
            ExamBottomControlBar(
                isLoading: $isLoading,
                exams: $exams,
                showAlert: $showAlert,
                alertTitle: $alertTitle,
                alertMessage: $alertMessage,
                errorRetryAction: $errorRetryAction,
                selectedYear: $selectedYear,
                selectedTerm: $selectedTerm,
                querySource: Binding(
                    get: { querySource },
                    set: { querySource = $0 }
                ),
                requestMFACode: { phone in
                    await requestMFACode(maskedPhone: phone)
                },
                requestShishanyouniMFACode: backendMFA.provider,
                scheduleQuery: scheduleQuery,
                examQuery: examQuery,
                onQuerySuccess: { }
            )
        }
        .navigationTitle("考试查询")
        .toolbar(.hidden, for: .tabBar)
        .navigationBarTitleDisplayMode(.large)
        .alert(alertTitle, isPresented: $showAlert)
        {
            if let retry = errorRetryAction {
                Button("重试", action: retry)
            }
            Button("好的", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showMFASheet)
        {
            MFACodeInputSheet(
                maskedPhone: mfaMaskedPhone,
                code: $mfaCode,
                onSendCode: $mfaSendCodeAction,
                onCancel: { resolveMFACode(nil) },
                onConfirm: { resolveMFACode(mfaCode.trimmingCharacters(in: .whitespacesAndNewlines)) }
            )
        }
        .shishanyouniMFA(backendMFA)
        .onDisappear { resolveMFACode(nil) }
        .onAppear
        {
            loadCachedExams()
        }
        .onChange(of: selectedYear)
        { _ in
            loadCachedExams()
        }
        .onChange(of: selectedTerm)
        { _ in
            loadCachedExams()
        }
        .onChange(of: querySourceRaw)
        { _ in
            loadCachedExams()
        }
    }

    private func loadCachedExams()
    {
        guard !userinfo.username.isEmpty else { return }
        exams = ExamStore.shared.loadExams(
            username: userinfo.username,
            year: selectedYear,
            term: selectedTerm,
            source: querySource
        )
    }
}

extension ExamView
{
    @MainActor
    private func requestMFACode(maskedPhone: String?) async -> String?
    {
        mfaMaskedPhone = maskedPhone ?? ""
        mfaCode = ""
        mfaSendCodeAction = MFACodeContext.activeSendCodeAction
        await Task.yield()
        showMFASheet = true
        return await withCheckedContinuation
        { continuation in
            mfaContinuation = continuation
        }
    }

    @MainActor
    private func resolveMFACode(_ code: String?)
    {
        showMFASheet = false
        mfaContinuation?.resume(returning: code)
        mfaContinuation = nil
        mfaSendCodeAction = nil
    }
}
