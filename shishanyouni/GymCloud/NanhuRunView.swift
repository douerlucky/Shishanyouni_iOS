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

    // 弹窗状态
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""

    private let runQuery = GymCloudQuery()

    var body: some View
    {
        ZStack
        {
            // 背景颜色
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            if runScores.isEmpty && !isLoading
            {
                VStack(spacing: 12)
                {
                    Image(systemName: "figure.run.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("暂无环湖跑数据")
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
                    .padding()
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
                        Text("正在同步南湖跑成绩...")
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
    }

    private func fetchData()
    {
        isLoading = true
        Task
        {
            do
            {
                // 1. 登录并获取双 Cookie
                let cookie = try await runQuery.loginAndGetRunCookie(
                    username: userinfo.username,
                    rsaPassword: userinfo.encryptedResult
                )

                // 2. 获取成绩
                let scores = try await runQuery.fetchRunScores(cookie: cookie)

                await MainActor.run
                {
                    self.runScores = scores
                    self.isLoading = false
                }
            }
            catch
            {
                await MainActor.run
                {
                    self.isLoading = false
                    self.alertTitle = "获取失败"
                    self.alertMessage = error.localizedDescription
                    self.showAlert = true
                }
            }
        }
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

#Preview
{
    NavigationStack
    {
        NanhuRunView()
            .environmentObject(userInfo())
    }
}
