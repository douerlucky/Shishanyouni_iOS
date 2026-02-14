//
//  PhysicalTestView.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/14.
//

import SwiftUI

func getScoreColor(score: Double) -> Color
{
    switch score
    {
    case ..<60: return .red
    case 60 ..< 80: return .orange
    case 80 ..< 90: return .blue
    default: return .green
    }
}

struct PhysicalTestView: View
{
    @EnvironmentObject var userinfo: userInfo
    @State private var physicalScore: PhysicalScore? = nil
    @State private var isLoading = false

    // 筛选状态 (参考 ExamView)
    @State var selectedYear = "2025-2026"
    @State var selectedTerm = "1"
    @State private var showPicker = false

    // 弹窗状态
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""

    private let gymQuery = GymCloudQuery()

    let years = ["2025-2026", "2024-2025", "2023-2024", "2022-2023"]

    var body: some View
    {
        ZStack(alignment: .bottom)
        {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0)
            {
                if let score = physicalScore
                {
                    ScrollView
                    {
                        VStack(alignment: .leading, spacing: 25)
                        {
                            // 顶部总分大圆环
                            HStack(spacing: 30)
                            {
                                MainScoreRing(score: Double(score.totalScore) ?? 0,totalGrade: score.totalGrade)
                                    .frame(width: 128, height: 128)

                                VStack(alignment: .leading, spacing: 8)
                                {
                                    

                                    Text("测试年度: \(score.testYear)")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.secondary)

                                    Text("结果更新时间:\n\(score.updateTime)")
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondary.opacity(0.8))

                                    HStack
                                    {
                                        Text(score.gradeLevel)

                                        Label(score.className, systemImage: "person.2.fill")
                                    }
                                }
                            }
                            .padding(20)
                            .frame(maxWidth:.infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                            )
                            .padding(.horizontal, 16)
                            

                            // 单项数据网格两列布局
                            VStack(alignment: .leading, spacing: 15)
                            {
                                Text("单项成绩")
                                    .font(.title2.bold())
                                    .foregroundColor(.primary)
                                    .padding(.horizontal)

                                let columns = [
                                    GridItem(.flexible(), spacing: 16),
                                    GridItem(.flexible())
                                ]
                                LazyVGrid(columns: columns, spacing: 16)
                                {
                                    ForEach(score.details, id: \.project)
                                    { detail in
                                        DetailCard(detail: detail)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.bottom, 100)
                    }
                }
                else if !isLoading
                {
                    emptyStateView
                }
            }

            // 底部悬浮筛选按钮
            PhysicalTestQueryButton(
                selectedYear: $selectedYear,
                showPicker: $showPicker,
                fetchPhysicalData: {
                    fetchPhysicalData()
                }
            )

            if isLoading
            {
                loadingOverlay
            }
        }
        .navigationTitle("体测成绩")
        .toolbar(.hidden, for: .tabBar)
        .navigationBarTitleDisplayMode(.automatic)
        .onAppear
        {
            fetchPhysicalData()
        }
        .sheet(isPresented: $showPicker)
        {
            termPickerView
        }
        .alert(isPresented: $showAlert)
        {
            Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("确定")))
        }
    }

    private var emptyStateView: some View
    {
        VStack(spacing: 20)
        {
            Spacer()
            Image(systemName: "medal.fill")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.3))
            Text("未查询到成绩")
                .font(.title3)
                .foregroundColor(.gray)
            Text("请尝试切换学年或重新登录")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.8))
            Spacer()
        }
    }

    private var termPickerView: some View
    {
        VStack
        {
            Text("切换查询学期").font(.headline).padding()
            HStack
            {
                Picker("年份", selection: $selectedYear)
                {
                    ForEach(years, id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.wheel)
            }
            Button("确定")
            {
                showPicker = false
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .presentationDetents([.height(300)])
    }

    private var loadingOverlay: some View
    {
        ZStack
        {
            // 使用材质效果替代纯色背景，这样更有高级感
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 15)
            {
                ProgressView()
                    .scaleEffect(1.5)
                Text("正在查询健康云...")
                    .font(.headline)
                    .foregroundColor(.secondary) // 👈 使用次级文字色
            }
        }
    }

    private func fetchPhysicalData()
    {
        isLoading = true
        Task
        {
            do
            {
                let cookie = try await gymQuery.loginAndGetRunCookie(
                    username: userinfo.username,
                    rsaPassword: userinfo.encryptedResult
                )
                let key = "\(selectedYear)_1"
                let result = try await gymQuery.fetchPhysicalScores(cookie: cookie, semesterKey: key)

                await MainActor.run
                {
                    self.physicalScore = result
                    self.isLoading = false
                    if result == nil
                    {
                        self.alertTitle = "提示"
                        self.alertMessage = "该时段暂无体测数据"
                        self.showAlert = true
                    }
                }
            }
            catch
            {
                await MainActor.run
                {
                    self.isLoading = false
                    self.alertTitle = "查询失败"
                    self.alertMessage = error.localizedDescription
                    self.showAlert = true
                }
            }
        }
    }

    private func gradeColor(_ grade: String) -> Color
    {
        switch grade
        {
        case "优秀": return .green
        case "良好": return .blue
        case "及格": return .orange
        default: return .red
        }
    }
}

struct MainScoreRing: View
{
    let score: Double
    let totalGrade: String
    var body: some View
    {
        ZStack
        {
            Circle()
                .stroke(getScoreColor(score: score).opacity(0.1), lineWidth: 15)
            Circle()
                .trim(from: 0, to: CGFloat(score / 100.0))
                .stroke(
                    getScoreColor(score: score),
                    style: StrokeStyle(lineWidth: 15, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: getScoreColor(score: score).opacity(0.3), radius: 5)

            VStack(spacing: 4)
            {
                Text(String(format: "%.1f", score))
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(getScoreColor(score: score))
                Text(totalGrade)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(getScoreColor(score: score))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                    .background(
                        getScoreColor(score: score).opacity(0.15)
                    )
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - 单项数据卡片

struct DetailCard: View
{
    let detail: PhysicalDetail

    var body: some View
    {
        VStack(alignment: .leading, spacing: 10)
        {
            Text(detail.project)
                .font(.system(size: 16))
                .foregroundColor(.secondary)

            HStack
            {
                Spacer()
                MiniScoreBadge(score: Double(detail.score)!)
                Spacer()
            }

            HStack
            {
                Text(detail.result)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                Text(detail.grade)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(gradeColor(detail.grade))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                    .background(
                        gradeColor(detail.grade).opacity(0.15)
                    )
                    .clipShape(Capsule())
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }

    private func gradeColor(_ grade: String) -> Color
    {
        if grade.contains("不") { return .red }
        if grade.contains("及格") { return .orange }
        return .green
    }
}

struct MiniScoreBadge: View
{
    let score: Double

    var body: some View
    {
        ZStack
        {
            // 底色细环
            Circle()
                .stroke(getScoreColor(score: score).opacity(0.1), lineWidth: 8)

            // 进度细环
            Circle()
                .trim(from: 0, to: CGFloat(score / 100.0))
                .stroke(
                    getScoreColor(score: score),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // 中间的文字，把之前的样式缩写进去
            Text(String(format: "%.0f", score))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(getScoreColor(score: score))
        }
        .frame(width: 64, height: 64) // 控制整体大小，28px 左右非常精致
        .padding(4)
    }
}

struct PhysicalTestQueryButton: View
{
    @Binding var selectedYear: String
    @Binding var showPicker: Bool

    var fetchPhysicalData: () -> Void

    var body: some View
    {
        HStack(spacing: 20)
        {
            // 学期选择按钮
            Button(action: { showPicker = true })
            {
                HStack
                {
                    Image(systemName: "calendar")
                    Text("\(selectedYear)")
                    Image(systemName: "chevron.up")
                        .font(.caption)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(Color.blue.opacity(0.15)) // 淡淡的蓝色底
                .foregroundColor(.blue)
                .clipShape(Capsule())
            }
            .optionalLiquidGlass()

            // 2. 刷新/查询按钮（中间核心位置）
            Button(action: {
                fetchPhysicalData()
            })
            {
                Text("同步成绩")
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
    PhysicalTestView().environmentObject(userInfo())
}
