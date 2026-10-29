import SwiftUI
import UIKit

private let gradeQueryTimestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    return formatter
}()

// MARK: - 主视图

struct GradeInquiry: View
{
    @EnvironmentObject var userinfo: userInfo
    @EnvironmentObject var iapStore: IAPStore
    @AppStorage(PreferenceKey.showCampusPassFeatures) private var showCampusPassFeatures = true
    @State var Grades: [Grade] = []
    @State private var isLoading = false

    @State private var showAlert   = false
    @State private var alertMessage = ""
    @State private var alertTitle   = ""
    @State private var errorRetryAction: (() -> Void)?

    @State var selectedYear: String
    @State var selectedTerm: String
    @AppStorage("gradeQuerySource") private var querySourceRaw = GradeQuerySource.shishanyouni.rawValue

    @State private var navigateToAnalysis = false
    @State private var navigateToSubscription = false
    @State private var selectedGradeForDetail: Grade?
    @State private var teachingSystemCookie: String?

    // MFA 验证码输入 Sheet 的状态；挂在父视图上，避免和学期选择 Sheet
    // 共享同一层级触发呈现冲突（曾导致“白屏一下再弹出授权”）。
    @State private var showMFASheet = false
    @State private var mfaMaskedPhone = ""
    @State private var mfaCode = ""
    @State private var mfaFromShishanyouni = true
    @State private var mfaSendCodeAction: (() async -> String?)?
    @State private var mfaContinuation: CheckedContinuation<String?, Never>?

    /// 被排除（不计入统计）的课程 ID 集合
    @State private var excludedIDs: Set<String> = []

    @StateObject private var backendMFA = ShishanyouniMFAPresenter()
    let gradeService = GradeAPI()

    init()
    {
        let semester = AcademicQuerySemester.forDate(Date())
        _selectedYear = State(initialValue: semester.year)
        _selectedTerm = State(initialValue: semester.term)
    }

    private var querySource: GradeQuerySource
    {
        get { GradeQuerySource(rawValue: querySourceRaw) ?? .shishanyouni }
        nonmutating set { querySourceRaw = newValue.rawValue }
    }

    private var hidesCampusPassContent: Bool
    {
        !showCampusPassFeatures
    }

    private var lastQueryText: String?
    {
        guard !userinfo.username.isEmpty,
              let date = GradeStore.shared.lastUpdatedAt(
                username: userinfo.username,
                year: selectedYear,
                term: selectedTerm,
                source: querySource
              ) else { return nil }
        return "上次查询：\(gradeQueryTimestampFormatter.string(from: date))"
    }

    /// 已勾选（计入统计）的课程
    private var includedGrades: [Grade]
    {
        Grades.filter { !excludedIDs.contains($0.id) }
    }

    var body: some View
    {
        ZStack(alignment: .bottom)
        {
            ZStack
            {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                if Grades.isEmpty
                {
                    VStack(spacing: 16)
                    {
                        if let lastQueryText
                        {
                            Text(lastQueryText)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.3))
                        Text("暂无成绩数据")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("选择学期后点击查询")
                            .font(.subheadline)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .blur(radius: isLoading ? 3 : 0)
                }
                else
                {
                    ScrollView
                    {
                        VStack(alignment: .leading, spacing: 20)
                        {
                            if let lastQueryText
                            {
                                Text(lastQueryText)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }

                            Text("总成绩")
                                .font(.title2.bold())
                                .padding(.horizontal, 16)

                            // 汇总卡片
                            GradeSummaryCard(
                                includedGrades: includedGrades,
                                allGrades: Grades
                            )

                            // 单科成绩网格
                            VStack(alignment: .leading, spacing: 12)
                            {
                                Text("单科成绩")
                                    .font(.title2.bold())
                                    .padding(.horizontal, 16)

                                if querySource != .teachingSystem
                                {
                                    Text("若要查看每科成绩的详细分数，请在下方选择使用教务系统进行查询")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 16)
                                }

                                let columns = [
                                    GridItem(.flexible(), spacing: 14),
                                    GridItem(.flexible())
                                ]
                                LazyVGrid(columns: columns, spacing: 14)
                                {
                                    ForEach(Grades) { item in
                                        GradeCard(
                                            grade: item,
                                            included: Binding(
                                                get: { !excludedIDs.contains(item.id) },
                                                set: { newVal in
                                                    if newVal { excludedIDs.remove(item.id) }
                                                    else      { excludedIDs.insert(item.id) }
                                                }
                                            ),
                                            showsDetailEntry: !hidesCampusPassContent && querySource == .teachingSystem,
                                            isDetailLocked: !iapStore.hasActiveSubscription,
                                            onShowDetail: {
                                                if iapStore.hasActiveSubscription
                                                {
                                                    selectedGradeForDetail = item
                                                }
                                                else
                                                {
                                                    navigateToSubscription = true
                                                }
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.bottom, 120)
                        .padding(.top, 8)
                    }
                    .blur(radius: isLoading ? 3 : 0)
                }

                if isLoading
                {
                    VStack(spacing: 15)
                    {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.blue)
                        Text("正在查询成绩")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 180, height: 120)
                    .background(Color(.systemBackground).opacity(0.95))
                    .cornerRadius(15)
                    .shadow(radius: 10)
                }
            }

            // 底部浮动操作栏
            BottomButtonView(
                isLoading: $isLoading,
                Grades: $Grades,
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
                teachingSystemCookie: $teachingSystemCookie,
                requestShishanyouniMFACode: backendMFA.provider,
                requestCASMFACode: { phone in
                    await requestCASMFACode(maskedPhone: phone)
                },
                gradeService: gradeService,
                onGradesLoaded: { excludedIDs = [] }   // 新查询时重置勾选
            )

        }
        .navigationTitle("成绩查询")
        .toolbar(.hidden, for: .tabBar)
        .navigationBarTitleDisplayMode(.large)
        .toolbar
        {
            if !Grades.isEmpty, !hidesCampusPassContent
            {
                ToolbarItemGroup(placement: .topBarTrailing)
                {
                    Button(action: {
                        if iapStore.hasActiveSubscription
                        {
                            // 下载已勾选的成绩视图，并根据保存结果反馈给用户。
                            exportGrade(grades: includedGrades) { result in
                                let feedback = UINotificationFeedbackGenerator()

                                switch result
                                {
                                case .success:
                                    feedback.notificationOccurred(.success)
                                    alertTitle = "保存成功"
                                    alertMessage = "已保存到相册"

                                case .failure(let error):
                                    feedback.notificationOccurred(.error)
                                    alertTitle = "保存失败"
                                    alertMessage = error.localizedDescription
                                }

                                // 导出提示不需要显示查询失败的“重试”按钮。
                                errorRetryAction = nil
                                showAlert = true
                            }
                        }
                        else
                        {
                            navigateToSubscription = true
                        }
                    }, label: {
                        Image(systemName: "square.and.arrow.down")
                    })
                    Button(action: {
                        if iapStore.hasActiveSubscription
                        {
                            navigateToAnalysis = true
                        }
                        else
                        {
                            navigateToSubscription = true
                        }
                    }, label: {
                        HStack(spacing: 4)
                        {
                            Image(systemName: "chart.bar.xaxis.ascending")
                            Text("分析")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    })

                }
            }
        }
        .navigationDestination(isPresented: $navigateToAnalysis)
        {
            GPAnalysisView()
                .environmentObject(userinfo)
        }
        .navigationDestination(isPresented: $navigateToSubscription)
        {
            SubscriptionView()
        }
        .sheet(item: $selectedGradeForDetail)
        { grade in
            NavigationStack
            {
                GradeDetailView(
                    grade: grade,
                    cookie: teachingSystemCookie,
                    fallbackStudentID: userinfo.username,
                    fallbackYear: selectedYear,
                    fallbackTerm: grade.xqm ?? teachingSystemTerms(for: selectedTerm).first ?? "3",
                    gradeService: gradeService
                )
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
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
                fromShishanyouni: mfaFromShishanyouni,
                onSendCode: $mfaSendCodeAction,
                onCancel: { resolveMFACode(nil) },
                onConfirm: { resolveMFACode(mfaCode.trimmingCharacters(in: .whitespacesAndNewlines)) }
            )
        }
        .shishanyouniMFA(backendMFA)
        .onDisappear { resolveMFACode(nil) }
        .onAppear
        {
            loadCachedGrades()
        }
        .onChange(of: selectedYear)
        { _ in
            loadCachedGrades()
        }
        .onChange(of: selectedTerm)
        { _ in
            loadCachedGrades()
        }
        .onChange(of: querySourceRaw)
        { _ in
            teachingSystemCookie = nil
            loadCachedGrades()
        }
        .onChange(of: userinfo.username)
        { _ in
            teachingSystemCookie = nil
            loadCachedGrades()
        }
    }

    private func loadCachedGrades()
    {
        guard !userinfo.username.isEmpty else { return }
        Grades = GradeStore.shared.loadGrades(
            username: userinfo.username,
            year: selectedYear,
            term: selectedTerm,
            source: querySource
        )
        excludedIDs = []
    }

    @MainActor
    private func requestCASMFACode(maskedPhone: String?) async -> String?
    {
        mfaFromShishanyouni = false
        mfaMaskedPhone = maskedPhone ?? "绑定手机号"
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
