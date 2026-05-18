//
//  NanhuRunView.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/14.
//

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

    private let runQuery = GymCloudQuery()

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
            Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("确定")))
        }
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
        guard !userinfo.username.isEmpty else
        {
            alertTitle = "获取失败"
            alertMessage = "好像忘记了登录，请先去登录吧！"
            showAlert = true
            return
        }

        isLoading = true
        Task
        {
            do
            {
                let scores: [RunScore]
                switch querySource
                {
                case .cas:
                    let cookie = try await runQuery.loginAndGetRunCookie(
                        username: userinfo.username,
                        rsaPassword: userinfo.encryptedPasswordSchool,
                        mfaCodeProvider: { phone in
                            await requestMFACode(maskedPhone: phone)
                        }
                    )

                    scores = try await runQuery.fetchRunScores(cookie: cookie)
                case .shishanyouni:
                    guard !userinfo.encryptedPasswordShishanyouni.isEmpty else
                    {
                        throw NanhuRunQueryError.apiError("未找到狮山有你绑定信息，请重新登录后再试。")
                    }
                    scores = try await fetchShishanyouniRunScoresWithMFA()
                }

                await MainActor.run
                {
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
                    self.alertTitle = "获取失败"
                    if(userinfo.username.isEmpty && userinfo.plainPassword.isEmpty)
                    {
                        self.alertMessage = "好像忘记了登录，请先去登录吧！"
                    }
                    else
                    {
                        self.alertMessage = error.localizedDescription
                    }
                    self.showAlert = true
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }
}

extension NanhuRunView {
    private func fetchShishanyouniRunScoresWithMFA() async throws -> [RunScore]
    {
        do
        {
            return try await runQuery.fetchRunScoresFromShishanyouni(
                username: userinfo.username,
                encryptedPassword: userinfo.encryptedPasswordShishanyouni,
                token: userinfo.shishanyouniToken
            )
        }
        catch ShishanyouniAPIError.needMFA(let phone, let sessionId, _)
        {
            try await refreshShishanyouniToken(phone: phone, sessionId: sessionId)
            return try await runQuery.fetchRunScoresFromShishanyouni(
                username: userinfo.username,
                encryptedPassword: userinfo.encryptedPasswordShishanyouni,
                token: userinfo.shishanyouniToken
            )
        }
    }

    private func refreshShishanyouniToken(phone: String, sessionId: String) async throws
    {
        guard let smsCode = await requestShishanyouniMFACode(maskedPhone: phone, sessionId: sessionId),
              !smsCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else
        {
            throw ShishanyouniAPIError.apiError(code: 22, message: "已取消短信验证码验证。")
        }

        let token = try await ShishanyouniMFAFlow.submitCode(sessionId: sessionId, smsCode: smsCode)
        await MainActor.run
        {
            userinfo.updateShishanyouniToken(token)
        }
    }

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
    private func requestShishanyouniMFACode(maskedPhone: String, sessionId: String) async -> String? {
        mfaMaskedPhone = maskedPhone
        mfaCode = ""
        mfaSendCodeAction = { await ShishanyouniMFAFlow.sendCodeMessage(sessionId: sessionId) }
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

/// 环湖跑小卡片组件
struct RunScoreCard: View
{
    let score: RunScore

    var body: some View
    {
        VStack(alignment: .leading, spacing: 15)
        {
            // 左上角：学年 + 学期
            HStack
            {
                HStack(spacing: 4)
                {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                    Text("\(score.schoolYear)学年 第\(score.semester)学期")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)

                Spacer()
            }

            // 中间：圈数放大显示
            VStack(spacing: 5)
            {
                Text(score.count)
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundColor(.primary)

                Text("已跑圈数")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
}

/// 模糊背景组件
struct BlurView: UIViewRepresentable
{
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView
    {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

struct NanhuRunQueryButton: View
{
    @Binding var querySource: NanhuRunQuerySource
    var fetchNanhuRunData: () -> Void

    var body: some View
    {
        HStack(spacing: 20)
        {
            QuerySourcePickerButton(
                selection: $querySource,
                fontSize: 15,
                horizontalPadding: 18,
                verticalPadding: 12,
                background: Color(uiColor: .systemBackground).opacity(0.92)
            )

            Button(action: {
                fetchNanhuRunData()
            })
            {
                Text("同步数据")
                    .font(.headline)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 25)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            .optionalLiquidGlass()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .glassBackground(cornerRadius: 64)
        .padding(.horizontal, 20)
        .padding(.bottom, 30) // 距离底部安全区域的距离
    }
}

#Preview
{
    NavigationStack
    {
        NanhuRunView()
            .environmentObject(userInfo())
    }
}
