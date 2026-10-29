import SwiftUI
import UIKit

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
    @EnvironmentObject var userinfo: userInfo
    /// MFA 验证码输入 Sheet 由父视图 GradeInquiry 统一呈现，避免和学期选择
    /// Sheet 挂在同一视图层级造成呈现冲突（白屏一下再弹出授权）。
    let requestShishanyouniMFACode: ShishanyouniV3MFAProvider
    let requestCASMFACode: @MainActor (_ maskedPhone: String?) async -> String?
    let gradeService: GradeAPI
    /// 成绩明细必须使用 jwgl 域会话，因此这里走教务系统专用 CAS service。
    private let scheduleQuery = SchoolAcademicAPI(
        serviceURL: SchoolAcademicAPI.jwglLoginServiceURL,
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
        case "1": term = "一"
        case "2": term = "二"
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
            DataSourceSelector(
                selection: $querySource,
                fontSize: 13
            )
            { source in
                switchSource(to: source)
            }
            .disabled(isLoading)

            SemesterSelector(title: selectionTitle, action: { showPicker = true })
            .disabled(isLoading)

            SearchButton("查询") { performGradeQuery() }
            .disabled(isLoading)
        }
        .queryBottomIndicatorBar()
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

                AcceptButton("确定") { showPicker = false }
                    .padding(.horizontal, 25)
                    .padding(.bottom)
            }
            .presentationDetents([.height(300)])
        }
        .onChange(of: selectedYear)
        { year in
            // 选择“所有成绩”时自动切换到全学年，确保请求的是全部学期。
            if year.isEmpty { selectedTerm = "0" }
        }
    }

    private func switchSource(to source: GradeQuerySource)
    {
        guard querySource != source else { return }
        querySource = source
        Grades = []
        teachingSystemCookie = nil
    }

    private func performGradeQuery()
    {
        guard !isLoading else { return }
        isLoading = true
        errorRetryAction = nil
        let account = userinfo.username
        let year = selectedYear
        let term = selectedTerm
        let source = querySource
        Task
        {
            do
            {
                let result: [Grade]
                var newTeachingSystemCookie: String?

                switch source
                {
                case .teachingSystem:
                    guard !userinfo.encryptedPasswordSchool.isEmpty else
                    {
                        throw NSError(
                            domain: "GradeService",
                            code: 401,
                            userInfo: [NSLocalizedDescriptionKey: "请先绑定\(SchoolServiceName.unifiedIdentity)账号。"]
                        )
                    }

                    let cookie = try await scheduleQuery.loginAndGetCookie(
                        username: account,
                        rsaPassword: userinfo.encryptedPasswordSchool,
                        mfaCodeProvider: requestCASMFACode
                    )
                    if term == "0"
                    {
                        result = try await gradeService.fetchAllYearGradesFromTeachingSystem(
                            cookie: cookie,
                            xnm: year
                        )
                    }
                    else
                    {
                        let teachingTerm = teachingSystemTerms(for: term)[0]
                        result = try await gradeService.fetchGradesFromTeachingSystem(
                            cookie: cookie,
                            xnm: year,
                            xqm: teachingTerm
                        )
                    }
                    newTeachingSystemCookie = cookie

                case .shishanyouni:
                    result = try await ShishanyouniGradeService(api: gradeService).fetchGrades(
                        username: account, encryptedPassword: userinfo.encryptedPasswordShishanyouni,
                        year: year, term: term, mfa: requestShishanyouniMFACode
                    )
                }

                await MainActor.run
                {
                    isLoading = false
                    guard userinfo.username == account, selectedYear == year, selectedTerm == term, querySource == source else { return }
                    Grades = result
                    if let newTeachingSystemCookie
                    {
                        teachingSystemCookie = newTeachingSystemCookie
                    }
                    GradeStore.shared.saveGrades(
                        Grades,
                        username: account,
                        year: year,
                        term: term,
                        source: source
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
                    guard userinfo.username == account, !(error is CancellationError) else { return }
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

    private func formatYearAbbreviation(_ year: String) -> String
    {
        if let y = Int(year)
        {
            return String(format: "%02d-%02d", y % 100, (y + 1) % 100)
        }
        return year
    }
}
