//
//  GradeView.swift
//  shishanyouni
//
//  Redesigned by douer_lucky
//

import SwiftUI
import UIKit

private let gradeQueryTimestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    return formatter
}()

/// 教务系统使用的学期值与 UI 不同：第一学期为 3，第二学期为 12。
/// “全学年”不能传 0，必须分别查询两个学期再合并。
private func teachingSystemTerms(for selectedTerm: String) -> [String]
{
    switch selectedTerm
    {
    case "1": return ["3"]
    case "2": return ["12"]
    default: return ["3", "12"]
    }
}

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
    /// 只有教务系统数据源才有可用的成绩明细接口。
    var showsDetailEntry = false
    /// 成绩明细属于校园通行证功能，未开通时显示锁定提示。
    var isDetailLocked = false
    var onShowDetail: (() -> Void)? = nil

    private var gpa: Double   { Double(grade.jd) ?? computeGPA(from: grade.cj) }
    private var color: Color  { included ? gpaColor(gpa) : .gray }

    var body: some View
    {
        // 整张卡片是一个明确的 Button，右上角勾选框是独立 Button。
        // 这样不会再依赖 ScrollView / LazyVGrid 中容易被竞争掉的 onTapGesture。
        ZStack(alignment: .topTrailing)
        {
            Button(action: { onShowDetail?() })
            {
                cardContent
            }
            .buttonStyle(.plain)
            .allowsHitTesting(showsDetailEntry)

            // 勾选状态只影响绩点统计，不会触发成绩明细弹窗。
            Button(action: { included.toggle() })
            {
                Image(systemName: included ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(included ? gpaColor(gpa) : .gray.opacity(0.5))
            }
            .buttonStyle(.plain)
            .padding(16)
        }
        .animation(.easeInOut(duration: 0.2), value: included)
    }

    private var cardContent: some View
    {
        VStack(alignment: .leading, spacing: 10)
        {
            Text(grade.kcmc)
                .font(.system(size: 14))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, 28)
                .frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)

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

            if showsDetailEntry
            {
                HStack(spacing: 5)
                {
                    Image(systemName: isDetailLocked ? "lock.fill" : "list.bullet.rectangle")
                    Text("成绩明细")
                    Spacer()
                    if isDetailLocked
                    {
                        Text("通行证")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isDetailLocked ? .secondary : .blue)
                .padding(.top, 2)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .contentShape(RoundedRectangle(cornerRadius: 20))
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
            let gpa = Double(g.jd) ?? computeGPA(from: g.cj)
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
    @EnvironmentObject var iapStore: IAPStore
    @AppStorage(PreferenceKey.showCampusPassFeatures) private var showCampusPassFeatures = true
    @State var Grades: [Grade] = []
    @State private var isLoading = false

    @State private var showAlert   = false
    @State private var alertMessage = ""
    @State private var alertTitle   = ""
    @State private var errorRetryAction: (() -> Void)?

    @State var selectedYear = "2025"
    @State var selectedTerm = "2"
    @AppStorage("gradeQuerySource") private var querySourceRaw = GradeQuerySource.shishanyouni.rawValue

    @State private var navigateToAnalysis = false
    @State private var navigateToSubscription = false
    @State private var selectedGradeForDetail: Grade?
    @State private var teachingSystemCookie: String?

    /// 被排除（不计入统计）的课程 ID 集合
    @State private var excludedIDs: Set<String> = []

    let gradeService = GradeService()

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
                gradeService: gradeService,
                onGradesLoaded: { excludedIDs = [] }   // 新查询时重置勾选
            )

            // 成绩明细使用页面中央的自定义弹窗，而不是底部 Sheet。
            if let grade = selectedGradeForDetail
            {
                Color.black.opacity(0.38)
                    .ignoresSafeArea()
                    .onTapGesture { selectedGradeForDetail = nil }
                    .zIndex(20)

                // 外层 ZStack 撑满屏幕，只负责居中；弹窗本身保持内容需要的高度。
                ZStack
                {
                    GradeDetailPopup(
                        grade: grade,
                        cookie: teachingSystemCookie,
                        fallbackStudentID: userinfo.username,
                        fallbackYear: selectedYear,
                        fallbackTerm: grade.xqm ?? teachingSystemTerms(for: selectedTerm).first ?? "3",
                        gradeService: gradeService,
                        onDismiss: { selectedGradeForDetail = nil }
                    )
                    .padding(.horizontal, 22)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .zIndex(21)
            }

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
        .alert(alertTitle, isPresented: $showAlert)
        {
            if let retry = errorRetryAction {
                Button("重试", action: retry)
            }
            Button("好的", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
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
}

// MARK: - 底部浮动按钮栏（保持原逻辑不变，新增 onGradesLoaded 回调）

struct BottomButtonView: View
{
    @Binding var isLoading: Bool
    @Binding var Grades: [Grade]
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    @Binding var errorRetryAction: (() -> Void)?
    @Binding var selectedYear: String
    @Binding var selectedTerm: String
    @Binding var querySource: GradeQuerySource
    @Binding var teachingSystemCookie: String?
    @State private var showPicker = false
    @State private var showMFASheet = false
    @State private var mfaMaskedPhone = ""
    @State private var mfaCode = ""
    @State private var mfaFromShishanyouni = true
    @State private var mfaSendCodeAction: (() async -> String?)?
    @State private var mfaContinuation: CheckedContinuation<String?, Never>?
    @EnvironmentObject var userinfo: userInfo
    let gradeService: GradeService
    /// 成绩明细必须使用 jwgl 域会话，因此这里走教务系统专用 CAS service。
    private let scheduleQuery = ScheduleQuery(
        serviceURL: ScheduleQuery.jwglLoginServiceURL,
        followServiceRedirects: true
    )
    /// 新数据加载完毕后调用（用于重置勾选状态）
    var onGradesLoaded: (() -> Void)? = nil

    /// 从账号入学年份推导可选学年，保留“所有成绩”入口，避免固定年份过期。
    private var years: [String]
    {
        let currentYear = Calendar.current.component(.year, from: Date())
        let enrollmentYear = Int(userinfo.username.prefix(4)) ?? max(2022, currentYear - 4)
        let endYear = max(enrollmentYear, currentYear)
        return (enrollmentYear...endYear).map(String.init)
    }

    /// UI 的“全学年”用 0 表示；教务系统会拆成第一、第二学期两次查询。
    private let terms = [("全学年", "0"), ("第一学期", "1"), ("第二学期", "2")]

    private var selectionTitle: String
    {
        let term: String
        switch selectedTerm
        {
        case "1": term = "上"
        case "2": term = "下"
        default: term = "全部"
        }
        if selectedYear.isEmpty { return "所有成绩 · \(term)" }
        return "\(formatYearAbbreviation(selectedYear)) · \(term)"
    }

    var body: some View
    {
        HStack(spacing: 8)
        {
            // 数据源、学期、查询保持一排；学期按钮使用固定紧凑宽度。
            QuerySourcePickerButton(
                selection: $querySource,
                fontSize: 13,
                horizontalPadding: 10,
                verticalPadding: 10
            )
            { source in
                switchSource(to: source)
            }
            .disabled(isLoading)

            // 学期选择按钮
            Button(action: { showPicker = true })
            {
                HStack(spacing: 4)
                {
                    Text(selectionTitle)
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .allowsTightening(true)
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                        .fixedSize()
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .background(Color(.systemBackground).opacity(0.9))
            .clipShape(Capsule())
            .optionalLiquidGlass()
            .frame(width: 112)
            .disabled(isLoading)

            Button(action: { performGradeQuery() })
            {
                Text("查询")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
            .optionalLiquidGlass()
            .clipShape(Capsule())
            .frame(width: 82)
            .disabled(isLoading)
        }
        .padding(10)
        .glassBackground(cornerRadius: 32)
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
                        Text("所有成绩").tag("")
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
        .onChange(of: selectedYear)
        { year in
            // 选择“所有成绩”时自动切换到全学年，确保请求的是全部学期。
            if year.isEmpty { selectedTerm = "0" }
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
    }

    private func switchSource(to source: GradeQuerySource)
    {
        guard querySource != source else { return }
        querySource = source
        Grades = []
        teachingSystemCookie = nil
    }

    private func fetchGradesWithMFA() async throws -> [Grade]
    {
        do
        {
            return try await gradeService.fetchGrades(
                username: userinfo.username,
                password: userinfo.encryptedPasswordShishanyouni,
                token: userinfo.shishanyouniToken,
                xnm: selectedYear,
                xqm: selectedTerm
            )
        }
        catch ShishanyouniAPIError.needMFA(let phone, let sessionId, _)
        {
            try await refreshShishanyouniToken(phone: phone, sessionId: sessionId)
            return try await gradeService.fetchGrades(
                username: userinfo.username,
                password: userinfo.encryptedPasswordShishanyouni,
                token: userinfo.shishanyouniToken,
                xnm: selectedYear,
                xqm: selectedTerm
            )
        }
    }

    private func performGradeQuery()
    {
        isLoading = true
        errorRetryAction = nil
        Task
        {
            do
            {
                let result: [Grade]
                var newTeachingSystemCookie: String?

                switch querySource
                {
                case .teachingSystem:
                    guard !userinfo.encryptedPasswordSchool.isEmpty else
                    {
                        throw NSError(
                            domain: "GradeService",
                            code: 401,
                            userInfo: [NSLocalizedDescriptionKey: "请先绑定教务系统账号。"]
                        )
                    }

                    let cookie = try await scheduleQuery.loginAndGetCookie(
                        username: userinfo.username,
                        rsaPassword: userinfo.encryptedPasswordSchool,
                        mfaCodeProvider: requestCASMFACode
                    )
                    if selectedTerm == "0"
                    {
                        result = try await gradeService.fetchAllYearGradesFromTeachingSystem(
                            cookie: cookie,
                            xnm: selectedYear
                        )
                    }
                    else
                    {
                        let teachingTerm = teachingSystemTerms(for: selectedTerm)[0]
                        result = try await gradeService.fetchGradesFromTeachingSystem(
                            cookie: cookie,
                            xnm: selectedYear,
                            xqm: teachingTerm
                        )
                    }
                    newTeachingSystemCookie = cookie

                case .shishanyouni:
                    result = try await fetchGradesWithMFA()
                }

                await MainActor.run
                {
                    isLoading = false
                    Grades = result
                    if let newTeachingSystemCookie
                    {
                        teachingSystemCookie = newTeachingSystemCookie
                    }
                    GradeStore.shared.saveGrades(
                        Grades,
                        username: userinfo.username,
                        year: selectedYear,
                        term: selectedTerm,
                        source: querySource
                    )
                    onGradesLoaded?()
                    alertTitle   = "查询成功"
                    alertMessage = "从\(querySource.title)一共找到了 \(Grades.count) 门课的成绩"
                    showAlert    = true
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
            catch
            {
                await MainActor.run
                {
                    isLoading = false
                    alertTitle = "哎呀，出错了"
                    if userinfo.username.isEmpty && userinfo.plainPassword.isEmpty
                    {
                        alertMessage = "好像忘记了登录，请先去登录吧！"
                    }
                    else
                    {
                        alertMessage = error.localizedDescription
                    }
                    errorRetryAction = { self.performGradeQuery() }
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    showAlert = true
                }
            }
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
    private func requestShishanyouniMFACode(maskedPhone: String, sessionId: String) async -> String?
    {
        mfaFromShishanyouni = true
        mfaMaskedPhone = maskedPhone
        mfaCode = ""
        mfaSendCodeAction = { await ShishanyouniMFAFlow.sendCodeMessage(sessionId: sessionId) }
        await Task.yield()
        showMFASheet = true
        return await withCheckedContinuation
        { continuation in
            mfaContinuation = continuation
        }
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
        .environmentObject(IAPStore.preview(hasActiveSubscription: false))
}
