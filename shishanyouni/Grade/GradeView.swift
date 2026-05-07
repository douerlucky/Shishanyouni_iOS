//
//  GradeView.swift
//  shishanyouni
//
//  Redesigned by douer_lucky
//

import SwiftUI

// MARK: - GPA 计算 & 颜色

/// 根据百分制成绩计算绩点（按学校标准）
private func computeGPA(from scoreStr: String) -> Double
{
    if let score = Double(scoreStr)
    {
        if score >= 90 { return 4.00 }
        if score >= 85 { return 3.70 }
        if score >= 82 { return 3.30 }
        if score >= 78 { return 3.00 }
        if score >= 75 { return 2.70 }
        if score >= 72 { return 2.30 }
        if score >= 68 { return 2.00 }
        if score >= 64 { return 1.50 }
        if score >= 60 { return 1.00 }
        return 0.00
    }
    // 非数字等级（优秀/良好/合格/通过 等）
    switch scoreStr
    {
    case "优秀":       return 4.00
    case "良好":       return 3.00
    case "中等":       return 2.00
    case "合格", "通过": return 1.00
    default:          return 0.00
    }
}

/// 根据百分制成绩计算平均分（非数字返回 nil）
private func computeScore(from scoreStr: String) -> Double?
{
    Double(scoreStr)
}

/// 根据绩点返回主题色
private func gpaColor(_ gpa: Double) -> Color
{
    if gpa >= 4.00 { return .green }
    if gpa >= 3.00 { return .blue }
    if gpa >= 1.00 { return .orange }
    return .red
}

/// 汇总绩点颜色（按大众分布放宽标准）
private func summaryGpaColor(_ gpa: Double) -> Color
{
    if gpa >= 3.70 { return .green }
    if gpa >= 3.30 { return .blue }
    if gpa >= 2.70 { return .orange }
    return .red
}

// MARK: - 绩点圆环

struct GPARing: View {
    let gpa: Double
    let color: Color
    var centerText: String? = nil
    var isSummary: Bool = false

    private var progress: Double { min(gpa / 4.0, 1.0) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: 9)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: gpa)

            VStack(spacing: 4) {
                Text(centerText ?? String(format: "%.2f", gpa))
                    .font(.system(size: isSummary ? 24 : 20, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                if isSummary {
                    Text("平均学分绩点")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(color.opacity(0.7))
                }
            }
        }
    }
}

// MARK: - 单门课程卡片

struct GradeCard: View
{
    let grade: Grade
    /// 是否计入绩点统计
    @Binding var included: Bool

    private var gpa: Double   { computeGPA(from: grade.cj) }
    private var color: Color  { included ? gpaColor(gpa) : .gray }

    var body: some View
    {
        VStack(alignment: .leading, spacing: 10)
        {
            // 顶栏：课程名 + 勾选框
            HStack(alignment: .top)
            {
                Text(grade.kcmc)
                    .font(.system(size: 14))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)

                // 右上角单选框
                Button(action: { included.toggle() })
                {
                    Image(systemName: included ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundColor(included ? gpaColor(gpa) : .gray.opacity(0.5))
                }
                .buttonStyle(.plain)
            }

            // 绩点圆环（居中）
            HStack
            {
                Spacer()
                GPARing(gpa: included ? gpa : 0, color: color)
                    .frame(width: 64, height: 64)
                Spacer()
            }

            // 成绩（左）+ 学分（右）
            HStack
            {
                VStack(spacing: 2)
                {
                    Text(grade.cj)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                    Text("成绩")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(spacing: 2)
                {
                    Text(grade.xf)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(included ? .primary : .secondary)
                    Text("学分")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 6)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .animation(.easeInOut(duration: 0.2), value: included)
    }
}

// MARK: - 顶部汇总卡片

struct GradeSummaryCard: View
{
    /// 仅传入已勾选的课程
    let includedGrades: [Grade]
    /// 全部课程（用于计算平均分）
    let allGrades: [Grade]

    // 计入统计的（绩点）
    private var validGrades: [(gpa: Double, xf: Double)]
    {
        includedGrades.compactMap
        { g in
            let gpa = computeGPA(from: g.cj)
            guard let xf = Double(g.xf) else { return nil }
            return (gpa, xf)
        }
    }

    /// 加权平均绩点 = Σ(学分×绩点) / Σ学分
    private var weightedGPA: Double
    {
        let totalXF  = validGrades.reduce(0.0) { $0 + $1.xf }
        let weighted = validGrades.reduce(0.0) { $0 + $1.gpa * $1.xf }
        guard totalXF > 0 else { return 0 }
        return weighted / totalXF
    }

    /// 算术平均分（仅数字成绩）
    private var averageScore: Double?
    {
        let scores = includedGrades.compactMap { computeScore(from: $0.cj) }
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / Double(scores.count)
    }

    /// 加权平均分 = Σ(学分×分数) / Σ学分
    private var weightedScore: Double?
    {
        let pairs = includedGrades.compactMap { g -> (Double, Double)? in
            guard let score = computeScore(from: g.cj),
                  let xf = Double(g.xf) else { return nil }
            return (score, xf)
        }
        guard !pairs.isEmpty else { return nil }
        let totalXF = pairs.reduce(0.0) { $0 + $1.1 }
        guard totalXF > 0 else { return nil }
        return pairs.reduce(0.0) { $0 + $1.0 * $1.1 } / totalXF
    }

    private var totalCredits: Double
    {
        validGrades.reduce(0.0) { $0 + $1.xf }
    }

    private var color: Color { summaryGpaColor(weightedGPA) }

    var body: some View
    {
        VStack(spacing: 16)
        {
            // 大圆：加权平均绩点
            GPARing(gpa: weightedGPA, color: color, isSummary: true)
                .frame(width: 120, height: 120)

            // 统计数据行
            HStack(spacing: 0)
            {
                // 平均分
                VStack(spacing: 4)
                {
                    if let avg = averageScore
                    {
                        Text(String(format: "%.2f", avg))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    else
                    {
                        Text("—")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    Text("平均分")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                // 分割线
                Divider()
                    .frame(height: 36)

                // 加权平均分
                VStack(spacing: 4)
                {
                    if let ws = weightedScore
                    {
                        Text(String(format: "%.2f", ws))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    else
                    {
                        Text("—")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    Text("加权平均分")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                // 分割线
                Divider()
                    .frame(height: 36)

                // 记录课程数 / 总学分
                VStack(spacing: 4)
                {
                    Text("\(includedGrades.count) 门")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("记录课程")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                // 分割线
                Divider()
                    .frame(height: 36)

                // 总学分
                VStack(spacing: 4)
                {
                    Text(String(format: "%.1f", totalCredits))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("总学分")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - 主视图

struct GradeInquiry: View
{
    @EnvironmentObject var userinfo: userInfo
    @State var Grades: [Grade] = []
    @State private var isLoading = false

    @State private var showAlert   = false
    @State private var alertMessage = ""
    @State private var alertTitle   = ""

    @State var selectedYear = "2025"
    @State var selectedTerm = "2"

    @State private var navigateToAnalysis = false

    /// 被排除（不计入统计）的课程 ID 集合
    @State private var excludedIDs: Set<String> = []

    let gradeService = GradeService()

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
                                            )
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
                selectedYear: $selectedYear,
                selectedTerm: $selectedTerm,
                gradeService: gradeService,
                onGradesLoaded: { excludedIDs = [] }   // 新查询时重置勾选
            )
        }
        .navigationTitle("成绩查询")
        .toolbar(.hidden, for: .tabBar)
        .navigationBarTitleDisplayMode(.large)
        .toolbar
        {
            if !Grades.isEmpty
            {
                ToolbarItem(placement: .topBarTrailing)
                {
                    Button(action: { navigateToAnalysis = true })
                    {
                        HStack(spacing: 4)
                        {
                            Image(systemName: "chart.bar.xaxis.ascending")
                            Text("分析")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                }
            }
        }
        .navigationDestination(isPresented: $navigateToAnalysis)
        {
            GPAnalysisView()
                .environmentObject(userinfo)
        }
        .alert(alertTitle, isPresented: $showAlert)
        {
            Button("好的", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
}

// MARK: - 底部浮动按钮栏（保持原逻辑不变，新增 onGradesLoaded 回调）

struct BottomButtonView: View
{
    @Binding var isLoading: Bool
    @Binding var Grades: [Grade]
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    @Binding var selectedYear: String
    @Binding var selectedTerm: String
    @State private var showPicker = false
    @EnvironmentObject var userinfo: userInfo
    let gradeService: GradeService
    /// 新数据加载完毕后调用（用于重置勾选状态）
    var onGradesLoaded: (() -> Void)? = nil

    let years = ["2022", "2023", "2024", "2025"]
    let terms = [("第一学期", "1"), ("第二学期", "2")]

    var body: some View
    {
        HStack(spacing: 15)
        {
            // 学期选择按钮
            Button(action: { showPicker = true })
            {
                HStack
                {
                    Text("\(formatYearAbbreviation(selectedYear)) \(selectedTerm == "1" ? "一" : "二")")
                        .font(.system(size: 14, weight: .bold))
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemBackground).opacity(0.9))
            .clipShape(Capsule())
            .optionalLiquidGlass()

            // 查询按钮
            Button(action: {
                isLoading = true
                Task
                {
                    defer { isLoading = false }
                    do
                    {
                        Grades = try await gradeService.fetchGrades(
                            username: userinfo.username,
                            password: userinfo.encryptedPasswordShishanyouni,
                            xnm: selectedYear,
                            xqm: selectedTerm
                        )
                        await MainActor.run
                        {
                            onGradesLoaded?()
                            alertTitle   = "查询成功"
                            alertMessage = "一共找到了 \(Grades.count) 门课的成绩"
                            showAlert    = true
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    }
                    catch
                    {
                        await MainActor.run
                        {
                            alertTitle = "哎呀，出错了"
                            if userinfo.username.isEmpty && userinfo.plainPassword.isEmpty
                            {
                                alertMessage = "好像忘记了登录，请先去登录吧！"
                            }
                            else
                            {
                                alertMessage = error.localizedDescription
                            }
                            UINotificationFeedbackGenerator().notificationOccurred(.error)
                            showAlert = true
                        }
                    }
                }
            })
            {
                Text("查询")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
            .optionalLiquidGlass()
            .clipShape(Capsule())
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 15)
        .glassBackground(cornerRadius: 64)
        .padding(.horizontal, 20)
        .padding(.bottom, 25)
        .sheet(isPresented: $showPicker)
        {
            VStack
            {
                Text("选择学期")
                    .font(.headline)
                    .padding(.top)

                HStack(spacing: 0)
                {
                    Picker("年份", selection: $selectedYear)
                    {
                        ForEach(years, id: \.self) { year in
                            if let y = Int(year)
                            {
                                Text("\(year)-\(String(y + 1))学年").tag(year)
                            }
                            else
                            {
                                Text("\(year)学年").tag(year)
                            }
                        }
                    }
                    .pickerStyle(.wheel)

                    Picker("学期", selection: $selectedTerm)
                    {
                        ForEach(terms, id: \.1) { Text($0.0).tag($0.1) }
                    }
                    .pickerStyle(.wheel)
                }

                Button("确定") { showPicker = false }
                    .optionalLiquidGlass()
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom)
            }
            .presentationDetents([.height(300)])
        }
    }

    private func formatYearAbbreviation(_ year: String) -> String
    {
        if let y = Int(year)
        {
            return String(format: "%02d-%02d", y % 100, (y + 1) % 100)
        }
        return year
    }
}

#Preview
{
    GradeInquiry()
        .environmentObject(userInfo())
}
