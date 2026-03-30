
import SwiftUI

struct ExamView: View
{
    @EnvironmentObject var userinfo: userInfo
    @State var exams: [Exam] = []
    @State private var isLoading = false

    // 弹窗状态
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""

    @State var selectedYear = "2025"
    @State var selectedTerm = "3" // 默认选秋季

    // 声明查询工具
    private let scheduleQuery = ScheduleQuery()
    private let examQuery = ExamQuery.shared

    var body: some View
    {
        ZStack(alignment: .bottom)
        {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            // 底层的考试列表
            ZStack
            {
                if exams.isEmpty
                {
                    VStack
                    {
                        Spacer()
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary.opacity(0.6))
                            .padding(.bottom, 8)
                        Text("未查询到任何考试安排")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .blur(radius: isLoading ? 3 : 0)
                }
                else
                {
                    List(exams)
                    { item in
                        ExamCard(exam: item)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .blur(radius: isLoading ? 3 : 0)
                    .safeAreaInset(edge: .bottom)
                    {
                        Color.clear.frame(height: 100)
                    }
                }

                if isLoading
                {
                    VStack(spacing: 12)
                    {
                        ProgressView()
                            .tint(.blue)
                        Text("正在努力加载考试信息...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(25)
                    .background(Color(.systemBackground).opacity(0.8))
                    .cornerRadius(15)
                    .shadow(radius: 5)
                }
            }

            // 浮动按钮区域 - 严格仿照 GradeView 的 UI 格式
            ExamBottomControlBar(
                isLoading: $isLoading,
                exams: $exams,
                showAlert: $showAlert,
                alertTitle: $alertTitle,
                alertMessage: $alertMessage,
                selectedYear: $selectedYear,
                selectedTerm: $selectedTerm,
                scheduleQuery: scheduleQuery,
                examQuery: examQuery
            )
        }
        .navigationTitle("我的考试")
        .toolbar(.hidden, for: .tabBar)
        .alert(alertTitle, isPresented: $showAlert)
        {
            Button("好的", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
}

// MARK: - 考试卡片组件

struct ExamCard: View
{
    let exam: Exam

    var body: some View
    {
        VStack(alignment: .leading, spacing: 12)
        {
            HStack(alignment: .top)
            {
                VStack(alignment: .leading, spacing: 4)
                {
                    Text(exam.kcmc)
                        .font(.title2)
                        .foregroundColor(.primary)

                    Text(exam.ksmc)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
                Spacer()
                if let xf = exam.xf
                {
                    Text("\(xf)学分")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8)
            {
                HStack
                {
                    Image(systemName: "calendar")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    Text(exam.examDate)
                        .font(.system(size: 20, weight: .semibold))
                    Text(exam.examTime)
                        .font(.system(size: 20, weight: .semibold))
                }

                HStack(spacing: 15)
                {
                    HStack
                    {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(.red)
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 16)
                        Text(exam.cdmc ?? "未指定场地")
                            .font(.system(size: 16, weight: .semibold))
                    }

                    if let zwh = exam.zwh, !zwh.isEmpty
                    {
                        HStack
                        {
                            Image(systemName: "number.square")
                                .foregroundColor(.green)
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 18)
                            Text("座位: \(zwh)")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
}

// MARK: - 底部控制条组件

struct ExamBottomControlBar: View
{
    @Binding var isLoading: Bool
    @Binding var exams: [Exam]
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    @Binding var selectedYear: String
    @Binding var selectedTerm: String

    @State private var showPicker = false
    @EnvironmentObject var userinfo: userInfo

    let scheduleQuery: ScheduleQuery
    let examQuery: ExamQuery

    let years = ["2023", "2024", "2025"]
    let terms = [("秋季学期", "3"), ("春季学期", "12")]

    var body: some View
    {
        HStack(spacing: 15)
        {
            // 学期选择器
            Button(action: { showPicker = true })
            {
                HStack
                {
                    Text("\(formatYearAbbreviation(selectedYear)) \(termShortName(selectedTerm))")
                        .font(.system(size: 14, weight: .bold))
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.systemBackground).opacity(0.9))
                .clipShape(Capsule())
            }
            .optionalLiquidGlass()

            // 查询按钮
            Button(action: {
                fetchExamData()
            })
            {
                HStack(spacing: 6)
                {
                    Image(systemName: "magnifyingglass")
                    Text("查询")
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color.blue)
                .clipShape(Capsule())
            }
            .optionalLiquidGlass()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 15)
        .glassBackground(cornerRadius: 64)
        .padding(.bottom, 25)

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

                Button(action: { showPicker = false })
                {
                    Text("确定")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .optionalLiquidGlass()
                .padding(.horizontal, 25)
                .padding(.bottom, 20)
            }
            .presentationDetents([.height(350)])
        }
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
        case "3": return "上"
        case "12": return "下"
        default:
            return "上"
        }
    }

    private func fetchExamData()
    {
        isLoading = true
        Task
        {
            do
            {
                // 1. 使用 ScheduleQuery 的登录流程获取有效的 Cookie (JSESSIONID)
                let cookie = try await scheduleQuery.loginAndGetCookie(
                    username: userinfo.username,
                    rsaPassword: userinfo.encryptedPasswordSchool
                )

                // 2. 使用获取到的 Cookie 进行考试查询
                let result = try await examQuery.fetchExams(
                    cookie: cookie,
                    xnm: selectedYear,
                    xqm: selectedTerm
                )

                await MainActor.run
                {
                    self.exams = result
                    self.isLoading = false
                    // 只有在数据为空时提示，避免正常有数据时弹窗打扰用户
                    if result.isEmpty
                    {
                        self.alertTitle = "提示"
                        self.alertMessage = "该学期未查询到考试安排"
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
                    self.alertTitle = "查询失败"
                    if(userinfo.username.isEmpty && userinfo.plainPassword.isEmpty)
                    {
                        self.alertMessage = "好像忘记了登录，请先去登录吧！"
                    }
                    else
                    {
                        self.alertMessage = error.localizedDescription
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    
                    self.showAlert = true
                }
            }
        }
    }
}

#Preview
{
    ExamView()
        .environmentObject(userInfo())
}
