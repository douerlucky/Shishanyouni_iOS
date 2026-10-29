import SwiftUI

struct AllCourseView: View
{
    @EnvironmentObject var userinfo: userInfo
    @State private var searchText: String = ""
    @State private var courses: [CourseInfo] = []
    @State private var isLoading = false
    /// 清除搜索或切换数据源后，用新的 ID 忽略旧请求的迟到响应，避免结果串台。
    @State private var searchRequestID = UUID()
    @State private var querySource: CourseQuerySource = .shishanyouni
    @State private var showMFASheet = false
    @State private var mfaMaskedPhone = ""
    @State private var mfaCode = ""
    @State private var mfaContinuation: CheckedContinuation<String?, Never>?
    @State private var mfaSendCodeAction: (() async -> String?)?
    // MARK: - Filter States

    @State var selectedYear = "2025"
    @State var selectedTerm = "12"
    @State private var showPicker = false

    let years = ["2023", "2024", "2025", "2026"]
    let terms = [("秋季学期", "3"), ("春季学期", "12")]

    private let scheduleQuery = SchoolAcademicAPI()

    var body: some View
    {
        NavigationStack
        {
            // 遮罩
            ZStack
            {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                Group
                {
                    if courses.isEmpty && !isLoading
                    {
                        VStack(spacing: 16)
                        {
                            Spacer()
                            Image(systemName: "magnifyingglass.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.blue)
                                .opacity(0.8)

                            VStack(spacing: 5)
                            {
                                Text(searchText.isEmpty ? "全校课程查询" : "未找到相关课程")
                                    .font(.title3)
                                    .fontWeight(.bold)

                                Text(searchText.isEmpty ? "使用上方搜索栏开始查询" : emptyHintText)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                    else
                    {
                        List(courses)
                        { course in
                            ZStack
                            {
                                NavigationLink(destination: CourseDetailView(course: course))
                                {
                                    EmptyView()
                                }
                                .opacity(0)
                                AllCourseCardRow(course: course)
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }

                // 不再让加载提示跟着底部搜索区偏移；ZStack 默认会把它放在页面中心。
                if isLoading
                {
                    ProgressView("正在查询课程…")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .navigationTitle("课程搜索")
            .navigationBarTitleDisplayMode(.automatic)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: searchPlaceholder
            )
            .onSubmit(of: .search)
            {
                performSearch()
            }
            .onChange(of: searchText)
            { newValue in
                // 原生搜索框的清除按钮代表回到初始查询状态，不能继续展示旧关键词的结果。
                if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                {
                    searchRequestID = UUID()
                    courses = []
                    isLoading = false
                }
            }
            .toolbar(.hidden, for: .tabBar)
            .toolbar
            {
                ToolbarItemGroup(placement: .topBarTrailing)
                {
                    if querySource == .cas
                    {
                        Button(action: { showPicker = true })
                        {
                            Image(systemName: "calendar")
                        }
                        .accessibilityLabel("选择查询学期：\(formatYearAbbreviation(selectedYear)) \(termShortName(selectedTerm))")
                    }

                    Menu
                    {
                        ForEach(CourseQuerySource.allCases)
                        { source in
                            Button
                            {
                                switchSource(to: source)
                            } label: {
                                if source == querySource
                                {
                                    Label(source.title, systemImage: "checkmark")
                                }
                                else
                                {
                                    Text(source.title)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("切换课程数据源，当前为\(querySource.title)")
                }
            }
            .sheet(isPresented: $showPicker)
            {
                VStack(spacing: 20)
                {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 40, height: 5)
                        .padding(.top, 10)

                    Text("选择查询学期")
                        .font(.headline)

                    HStack(spacing: 0)
                    {
                        Picker("年份", selection: $selectedYear)
                        {
                            ForEach(years, id: \.self)
                            { year in
                                if let yearInt = Int(year)
                                {
                                    Text("\(year)-\(String(yearInt + 1))学年").tag(year)
                                }
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 180)

                        Picker("学期", selection: $selectedTerm)
                        {
                            ForEach(terms, id: \.1) { Text($0.0).tag($0.1) }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 150)
                    }

                    AcceptButton("确定") {
                        showPicker = false
                        if !searchText.isEmpty { performSearch() }
                    }
                    .padding(.horizontal, 25)
                    .padding(.bottom, 20)
                }
                .presentationDetents([.height(350)])
            }
            .sheet(isPresented: $showMFASheet)
            {
                MFACodeInputSheet(
                    maskedPhone: mfaMaskedPhone,
                    code: $mfaCode,
                    onSendCode: $mfaSendCodeAction,
                    onCancel: { resolveMFACode(nil) },
                    onConfirm: { resolveMFACode(mfaCode.trimmingCharacters(in: .whitespacesAndNewlines)) }
                )
            }
        }
    }

    // MARK: - Logic Functions

    func performSearch()
    {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else
        {
            courses = []
            return
        }
        // 统一用清理后的关键词请求，避免仅输入空格时仍向两个数据源发起查询。
        searchText = keyword
        let requestID = UUID()
        searchRequestID = requestID
        let source = querySource
        let year = selectedYear
        let term = selectedTerm
        isLoading = true

        Task
        {
            do
            {
                let result: [CourseInfo]
                switch source
                {
                case .cas:
                    let cookie = try await scheduleQuery.loginAndGetCookie(
                        username: userinfo.username,
                        rsaPassword: userinfo.encryptedPasswordSchool,
                        mfaCodeProvider: { phone in
                            await requestMFACode(maskedPhone: phone)
                        }
                    )

                    result = try await CourseAPI.shared.fetchAllCourses(
                        cookie: cookie,
                        xnm: year,
                        xqm: term,
                        kch: keyword
                    )
                case .shishanyouni:
                    result = try await CourseAPI.shared.fetchLionCourses(keyword: keyword)
                }

                await MainActor.run
                {
                    guard searchRequestID == requestID else { return }
                    withAnimation(.spring())
                    {
                        self.courses = result
                    }
                    self.isLoading = false
                }
            }
            catch
            {
                print("AllCourse查询失败: \(error)")
                await MainActor.run
                {
                    guard searchRequestID == requestID else { return }
                    self.isLoading = false
                }
            }
        }
    }

    private func formatYearAbbreviation(_ year: String) -> String
    {
        if let yearInt = Int(year)
        {
            return String(format: "%02d-%02d", yearInt % 100, (yearInt + 1) % 100)
        }
        return year
    }

    private func termShortName(_ term: String) -> String
    {
        switch term
        {
        case "3": return "秋季"
        case "12": return "春季"
        default: return "未知"
        }
    }

    private var searchPlaceholder: String
    {
        switch querySource
        {
        case .cas:
            return "输入课程名称或代码"
        case .shishanyouni:
            return "输入课程名、教师名或教学班"
        }
    }

    private var emptyHintText: String
    {
        switch querySource
        {
        case .cas:
            return "换个关键词，或者切换学期试试看吧"
        case .shishanyouni:
            return "可以试试课程名、教师名或教学班"
        }
    }

    private func switchSource(to source: CourseQuerySource)
    {
        guard querySource != source else { return }
        querySource = source
        searchRequestID = UUID()
        courses = []
        isLoading = false
    }
}

extension AllCourseView
{
    @MainActor
    private func requestMFACode(maskedPhone: String?) async -> String?
    {
        mfaMaskedPhone = maskedPhone ?? ""
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
}
