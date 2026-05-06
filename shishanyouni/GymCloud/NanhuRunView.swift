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
                    scores = try await runQuery.fetchRunScoresFromShishanyouni(
                        username: userinfo.username,
                        encryptedPassword: userinfo.encryptedPasswordShishanyouni
                    )
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
    @MainActor
    private func requestMFACode(maskedPhone: String?) async -> String? {
        mfaMaskedPhone = maskedPhone ?? ""
        mfaCode = ""
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
    @State private var showSourcePicker = false

    var body: some View
    {
        HStack(spacing: 20)
        {
            Button(action: {
                showSourcePicker = true
            })
            {
                HStack(spacing: 6)
                {
                    Text(querySource.title)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                }
                .font(.system(size: 15, weight: .bold))
                .padding(.vertical, 12)
                .padding(.horizontal, 18)
                .background(Color(uiColor: .systemBackground).opacity(0.92))
                .foregroundColor(.primary)
                .clipShape(Capsule())
            }
            .optionalLiquidGlass()

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
        .sheet(isPresented: $showSourcePicker)
        {
            VStack(spacing: 18)
            {
                VStack(spacing: 6)
                {
                    Text("选择数据源")
                        .font(.headline)
                }
                .padding(.horizontal, 28)

                VStack(spacing: 12)
                {
                    ForEach(NanhuRunQuerySource.allCases)
                    { source in
                        Button(action: {
                            querySource = source
                            showSourcePicker = false
                        })
                        {
                            HStack
                            {
                                Text(source.title)
                                    .font(.system(size: 17, weight: .bold))
                                Spacer()
                                if querySource == source
                                {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.blue)
                                }
                            }
                            .foregroundColor(querySource == source ? .blue : .primary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 15)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(querySource == source ? Color.blue.opacity(0.12) : Color.secondary.opacity(0.1))
                            )
                            .optionalLiquidGlass()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)

                Button("取消")
                {
                    showSourcePicker = false
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.top, 24)
                .buttonStyle(.plain)
            }
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.hidden)
        }
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
