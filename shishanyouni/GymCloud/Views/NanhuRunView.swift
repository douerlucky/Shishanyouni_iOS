import SwiftUI

struct NanhuRunView: View
{
    @EnvironmentObject var userinfo: userInfo
    @State private var runScores: [RunScore] = []
    @State private var isLoading = false
    @State private var querySource: NanhuRunQuerySource = .cas
    @State private var hasLoadedScores = false

    // 弹窗状态
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var showMFASheet = false
    @State private var mfaMaskedPhone = ""
    @State private var mfaCode = ""
    @State private var mfaContinuation: CheckedContinuation<String?, Never>?
    @State private var mfaSendCodeAction: (() async -> String?)?
    @State private var errorRetryAction: (() -> Void)?

    @StateObject private var backendMFA = ShishanyouniMFAPresenter()
    private let runQuery = GymCloudAPI()

    var body: some View
    {
        ZStack()
        {
            // 背景颜色
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            if runScores.isEmpty && !isLoading
            {
                VStack(spacing: 12)
                {
                    Image(systemName: hasLoadedScores ? "figure.run.circle" : "arrow.clockwise.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text(hasLoadedScores ? "暂无环湖跑数据" : "点击下方按钮同步数据")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
            else
            {
                ScrollView
                {
                    LazyVStack(spacing: 16)
                    {
                        ForEach(runScores)
                        { score in
                            RunScoreCard(score: score)
                        }
                    }
                    .padding(.bottom,120)
                }
            }

            // 加载指示器
            if isLoading
            {
                ZStack
                {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()

                    VStack(spacing: 15)
                    {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("正在通过\(querySource.title)同步南湖跑成绩...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(25)
                    .background(
                        BlurView(style: .systemUltraThinMaterialDark)
                            .cornerRadius(20)
                    )
                }
            }

            VStack
            {
                Spacer()
                NanhuRunQueryButton(
                    querySource: $querySource,
                    fetchNanhuRunData: { fetchData() }
                )
                .disabled(isLoading)
            }
        }
        .navigationTitle("环湖跑成绩")
        .toolbar(.hidden, for: .tabBar)
        .navigationBarTitleDisplayMode(.automatic)
        .onAppear
        {
            fetchData()
        }
        .alert(isPresented: $showAlert)
        {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                primaryButton: .default(Text("重试"), action: { errorRetryAction?() }),
                secondaryButton: .cancel(Text("确定"))
            )
        }
        .shishanyouniMFA(backendMFA)
        .onDisappear { resolveMFACode(nil) }
        .sheet(isPresented: $showMFASheet) {
            MFACodeInputSheet(
                maskedPhone: mfaMaskedPhone,
                code: $mfaCode,
                onSendCode: $mfaSendCodeAction,
                onCancel: { resolveMFACode(nil) },
                onConfirm: { resolveMFACode(mfaCode.trimmingCharacters(in: .whitespacesAndNewlines)) }
            )
        }
    }

    private func fetchData()
    {
        guard !isLoading else { return }
        guard !userinfo.username.isEmpty else
        {
            alertTitle = "获取失败"
            alertMessage = "好像忘记了登录，请先去登录吧！"
            errorRetryAction = { self.fetchData() }
            showAlert = true
            return
        }

        let account = userinfo.username
        let source = querySource
        isLoading = true
        errorRetryAction = nil
        Task
        {
            do
            {
                let scores: [RunScore]
                switch source
                {
                case .cas:
                    let cookie = try await runQuery.loginAndGetRunCookie(
                        username: account,
                        rsaPassword: userinfo.encryptedPasswordSchool,
                        mfaCodeProvider: { phone in
                            await requestMFACode(maskedPhone: phone)
                        }
                    )

                    scores = try await runQuery.fetchRunScores(cookie: cookie)
                case .shishanyouni:
                    scores = try await runQuery.fetchRunScoresFromShishanyouni(
                        username: account, encryptedPassword: userinfo.encryptedPasswordShishanyouni,
                        mfa: backendMFA.provider
                    )
                }

                await MainActor.run
                {
                    guard userinfo.username == account, querySource == source else { self.isLoading = false; return }
                    self.runScores = scores
                    self.hasLoadedScores = true
                    self.isLoading = false
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
            catch
            {
                await MainActor.run
                {
                    self.isLoading = false
                    guard userinfo.username == account, !(error is CancellationError) else { return }
                    self.alertTitle = "获取失败"
                    if(userinfo.username.isEmpty && userinfo.plainPassword.isEmpty)
                    {
                        self.alertMessage = "好像忘记了登录，请先去登录吧！"
                    }
                    else
                    {
                        self.alertMessage = error.localizedDescription
                    }
                    self.errorRetryAction = { [self] in fetchData() }
                    self.showAlert = true
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }
}

extension NanhuRunView {
    @MainActor
    private func requestMFACode(maskedPhone: String?) async -> String? {
        mfaMaskedPhone = maskedPhone ?? ""
        mfaCode = ""
        mfaSendCodeAction = MFACodeContext.activeSendCodeAction
        await Task.yield()
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
        mfaSendCodeAction = nil
    }
}
