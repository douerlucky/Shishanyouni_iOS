import Combine
import EventKit
import SwiftUI

// MARK: - 底部控制条组件

struct ExamBottomControlBar: View
{
    @Binding var isLoading: Bool
    @Binding var exams: [Exam]
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    @Binding var errorRetryAction: (() -> Void)?
    @Binding var selectedYear: String
    @Binding var selectedTerm: String
    @Binding var querySource: ExamQuerySource

    @State private var showPicker = false
    @EnvironmentObject var userinfo: userInfo

    let requestMFACode: MFACodeProvider
    let requestShishanyouniMFACode: ShishanyouniV3MFAProvider
    let scheduleQuery: SchoolAcademicAPI
    let examQuery: ExamAPI
    let onQuerySuccess: () -> Void

    private var years: [String]
    {
        let currentYear = Calendar.current.component(.year, from: Date())
        let enrollmentYear = Int(userinfo.username.prefix(4)) ?? max(2022, currentYear - 4)
        return (enrollmentYear...max(enrollmentYear, currentYear)).map(String.init)
    }
    let terms = [("第一学期", "1"), ("第二学期", "2")]

    private var selectionTitle: String
    {
        "\(formatYearAbbreviation(selectedYear)) · \(termShortName(selectedTerm))"
    }

    var body: some View
    {
        HStack(spacing: 8)
        {
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

            // 查询按钮
            SearchButton("查询") { fetchExamData() }
            .disabled(isLoading)
        }
        .queryBottomIndicatorBar()

        .sheet(isPresented: $showPicker)
        {
            VStack(spacing: 20)
            {
                Text("选择查询范围")
                    .font(.headline)
                    .padding(.top, 20)

                HStack(spacing: 0)
                {
                    Picker("年份", selection: $selectedYear)
                    {
                        ForEach(years, id: \.self)
                        { year in
                            // 将字符串转为 Int 算下一年，再拼接起来
                            if let yearInt = Int(year)
                            {
                                Text("\(year)-\(String(yearInt + 1))学年")
                                    .tag(year)
                            }
                            else
                            {
                                Text("\(year)学年")
                                    .tag(year)
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
                .padding(.bottom, 20)
            }
            .presentationDetents([.height(350)])
        }
    }

    private func switchSource(to source: ExamQuerySource)
    {
        guard querySource != source else { return }
        querySource = source
        exams = []
    }

    private func formatYearAbbreviation(_ year: String) -> String
    {
        if let yearInt = Int(year)
        {
            let start = yearInt % 100
            let end = (yearInt + 1) % 100
            return String(format: "%02d-%02d", start, end)
        }
        return year
    }

    private func termShortName(_ term: String) -> String
    {
        switch term
        {
        case "1": return "一"
        case "2": return "二"
        default:
            return "一"
        }
    }

    private func fetchExamData()
    {
        guard !isLoading else { return }
        guard !userinfo.username.isEmpty
        else
        {
            alertTitle = "查询失败"
            alertMessage = "好像忘记了登录，请先去登录吧！"
            errorRetryAction = { self.fetchExamData() }
            showAlert = true
            return
        }

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
                let result: [Exam]
                switch source
                {
                // 数据源是cas
                case .cas:
                    let cookie = try await scheduleQuery.loginAndGetCookie(
                        username: account,
                        rsaPassword: userinfo.encryptedPasswordSchool,
                        mfaCodeProvider: requestMFACode
                    )
                    result = try await examQuery.fetchExams(
                        cookie: cookie,
                        xnm: year,
                        xqm: term == "1" ? "3" : "12"
                    )
                // 数据源是狮山有你
                case .shishanyouni:
                    result = try await examQuery.fetchExamsFromShishanyouni(
                        username: account, encryptedPassword: userinfo.encryptedPasswordShishanyouni,
                        xnm: year, xqm: term, mfa: requestShishanyouniMFACode
                    )
                }

                await MainActor.run
                {
                    self.isLoading = false
                    guard userinfo.username == account, selectedYear == year, selectedTerm == term, querySource == source else { return }
                    self.exams = result
                    ExamStore.shared.saveExams(
                        result,
                        username: account,
                        year: year,
                        term: term,
                        source: source
                    )
                    self.onQuerySuccess()
                    if result.isEmpty
                    {
                        self.alertTitle = "提示"
                        self.alertMessage = "\(querySource.title) 服务器下该学期未查询到考试安排"
                        self.showAlert = true
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
            catch
            {
                await MainActor.run
                {
                    self.isLoading = false
                    guard userinfo.username == account, !(error is CancellationError) else { return }
                    self.alertTitle = "查询失败"
                    if userinfo.username.isEmpty && userinfo.plainPassword.isEmpty
                    {
                        self.alertMessage = "好像忘记了登录，请先去登录吧！"
                    }
                    else
                    {
                        self.alertMessage = error.localizedDescription
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    self.errorRetryAction = { self.fetchExamData() }
                    self.showAlert = true
                }
            }
        }
    }
}
