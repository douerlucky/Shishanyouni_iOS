
import EventKit
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
    @State private var showMFASheet = false
    @State private var mfaMaskedPhone = ""
    @State private var mfaCode = ""
    @State private var mfaContinuation: CheckedContinuation<String?, Never>?

    @State var selectedYear = "2025"
    @State var selectedTerm = "2"
    @AppStorage("examQuerySource") private var querySourceRaw = ExamQuerySource.cas.rawValue

    private var querySource: ExamQuerySource
    {
        get { ExamQuerySource(rawValue: querySourceRaw) ?? .cas }
        nonmutating set { querySourceRaw = newValue.rawValue }
    }

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
                querySource: Binding(
                    get: { querySource },
                    set: { querySource = $0 }
                ),
                requestMFACode: { phone in
                    await requestMFACode(maskedPhone: phone)
                },
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
        .sheet(isPresented: $showMFASheet)
        {
            MFACodeInputSheet(
                maskedPhone: mfaMaskedPhone,
                code: $mfaCode,
                onCancel: { resolveMFACode(nil) },
                onConfirm: { resolveMFACode(mfaCode.trimmingCharacters(in: .whitespacesAndNewlines)) }
            )
        }
        .onAppear
        {
            loadCachedExams()
        }
        .onChange(of: selectedYear)
        { _ in
            loadCachedExams()
        }
        .onChange(of: selectedTerm)
        { _ in
            loadCachedExams()
        }
        .onChange(of: querySourceRaw)
        { _ in
            loadCachedExams()
        }
    }
}

extension ExamView
{
    private var examCacheParts: [String]
    {
        [querySource.rawValue, selectedYear, selectedTerm]
    }

    private func loadCachedExams()
    {
        guard !userinfo.username.isEmpty else { return }
        exams = AcademicQueryCache.load(
            [Exam].self,
            namespace: "exam",
            username: userinfo.username,
            parts: examCacheParts
        ) ?? []
    }

    @MainActor
    private func requestMFACode(maskedPhone: String?) async -> String?
    {
        mfaMaskedPhone = maskedPhone ?? ""
        mfaCode = ""
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
    }
}

// MARK: - 考试卡片组件

struct ExamCard: View
{
    let exam: Exam
    @State private var isAddingToCalendar = false
    @State private var showCalendarAlert = false
    @State private var calendarAlertTitle = ""
    @State private var calendarAlertMessage = ""

    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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

                VStack(alignment: .trailing, spacing: 8)
                {
                    if let xf = exam.xf
                    {
                        Text("\(xf)学分")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    Button(action: {
                        Task { await addExamToCalendar() }
                    })
                    {
                        HStack(spacing: 5)
                        {
                            Image(systemName: isAddingToCalendar ? "hourglass" : "calendar.badge.plus")
                                .font(.system(size: 13, weight: .bold))
                            Text("日历")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isAddingToCalendar)
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

                    HStack
                    {
                        Image(systemName: "number.square")
                            .foregroundColor(.green)
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 18)
                        Text(exam.seatDisplayText)
                            .font(.system(size: 16, weight: .semibold))
                    }
                }

                if let startDate = exam.examStartDate
                {
                    CountdownView(now: now, examStartDate: startDate)
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
        .onReceive(timer) { _ in
            now = Date()
        }
        .alert(calendarAlertTitle, isPresented: $showCalendarAlert)
        {
            Button("好的", role: .cancel) { }
        } message: {
            Text(calendarAlertMessage)
        }
    }

    @MainActor
    private func setCalendarAlert(title: String, message: String)
    {
        calendarAlertTitle = title
        calendarAlertMessage = message
        showCalendarAlert = true
    }

    private func addExamToCalendar() async
    {
        await MainActor.run { isAddingToCalendar = true }
        defer {
            Task { @MainActor in
                isAddingToCalendar = false
            }
        }

        do
        {
            let store = EKEventStore()
            let granted = try await requestCalendarAccess(store)
            guard granted else
            {
                await setCalendarAlert(title: "无法添加", message: "需要允许访问系统日历，才可以帮你把考试安排塞进去哦。")
                return
            }

            let (startDate, endDate) = try parseExamDateRange()
            if hasExistingEvent(in: store, startDate: startDate, endDate: endDate)
            {
                await setCalendarAlert(title: "已经添加过啦", message: "系统日历里已经有这场考试，不会重复添加。")
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                return
            }

            guard let calendar = store.defaultCalendarForNewEvents else
            {
                await setCalendarAlert(title: "添加失败", message: "没有找到可以写入的默认日历。")
                return
            }

            let event = EKEvent(eventStore: store)
            event.title = exam.kcmc
            event.startDate = startDate
            event.endDate = endDate
            event.calendar = calendar
            event.location = examLocation
            event.notes = "考试类型：\(exam.ksmc)"
            event.alarms = [EKAlarm(relativeOffset: -24 * 60 * 60)]

            try store.save(event, span: .thisEvent, commit: true)
            await setCalendarAlert(title: "添加成功", message: "已添加到系统日历，并设置为考前 1 天提醒。")
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        catch
        {
            await setCalendarAlert(title: "添加失败", message: error.localizedDescription)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private var examLocation: String
    {
        let room = (exam.cdmc ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return room.isEmpty ? "华中农业大学" : "华中农业大学\(room)"
    }

    private func requestCalendarAccess(_ store: EKEventStore) async throws -> Bool
    {
        try await withCheckedThrowingContinuation
        { continuation in
            if #available(iOS 17.0, *)
            {
                store.requestFullAccessToEvents
                { granted, error in
                    if let error
                    {
                        continuation.resume(throwing: error)
                    }
                    else
                    {
                        continuation.resume(returning: granted)
                    }
                }
            }
            else
            {
                store.requestAccess(to: .event)
                { granted, error in
                    if let error
                    {
                        continuation.resume(throwing: error)
                    }
                    else
                    {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }

    private func parseExamDateRange() throws -> (Date, Date)
    {
        guard let dateText = exam.examDate.firstMatch(of: #"\d{4}-\d{1,2}-\d{1,2}"#) else
        {
            throw CalendarAddError.invalidExamDate
        }

        let normalizedTime = exam.examTime
            .replacingOccurrences(of: "－", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
        let parts = normalizedTime
            .components(separatedBy: "-")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard parts.count >= 2 else
        {
            throw CalendarAddError.invalidExamTime
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        guard let startDate = formatter.date(from: "\(dateText) \(parts[0])"),
              let endDate = formatter.date(from: "\(dateText) \(parts[1])"),
              endDate > startDate
        else
        {
            throw CalendarAddError.invalidExamTime
        }

        return (startDate, endDate)
    }

    private func hasExistingEvent(in store: EKEventStore, startDate: Date, endDate: Date) -> Bool
    {
        let predicate = store.predicateForEvents(
            withStart: startDate.addingTimeInterval(-60),
            end: endDate.addingTimeInterval(60),
            calendars: nil
        )

        return store.events(matching: predicate).contains
        { event in
            event.title == exam.kcmc
                && abs(event.startDate.timeIntervalSince(startDate)) < 60
                && abs(event.endDate.timeIntervalSince(endDate)) < 60
        }
    }
}

private struct CountdownView: View
{
    let now: Date
    let examStartDate: Date

    private var isPast: Bool { now >= examStartDate }

    private var components: DateComponents
    {
        Calendar.current.dateComponents([.day, .hour, .minute, .second], from: now, to: examStartDate)
    }

    private var displayText: String
    {
        guard let d = components.day, let h = components.hour, let m = components.minute, let s = components.second else {
            return ""
        }
        if isPast { return "考试已结束" }
        let totalHours = d * 24 + h
        if totalHours <= 0 {
            if m <= 0 {
                return "\(s)秒后"
            }
            return "\(m)分\(s)秒后"
        }
        if totalHours < 24 {
            return "\(totalHours)时\(m)分后"
        }
        if d < 3 {
            return "\(d)天\(h)时后"
        }
        return "还有\(d)天"
    }

    private var accentColor: Color
    {
        if isPast { return .secondary }
        guard let d = components.day, let h = components.hour, let m = components.minute else {
            return .secondary
        }
        let totalHours = d * 24 + h
        if totalHours <= 0 && m < 30 { return .red }
        if totalHours < 24 { return .orange }
        return .blue
    }

    private var iconName: String
    {
        if isPast { return "checkmark.circle.fill" }
        guard let d = components.day, let h = components.hour else { return "hourglass" }
        let totalHours = d * 24 + h
        if totalHours <= 0 { return "timer" }
        if totalHours < 72 { return "hourglass" }
        return "clock"
    }

    var body: some View
    {
        HStack(spacing: 6)
        {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .semibold))
            Text(displayText)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(accentColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(accentColor.opacity(0.1))
        .cornerRadius(8)
        .padding(.top, 2)
    }
}

private enum CalendarAddError: LocalizedError
{
    case invalidExamDate
    case invalidExamTime

    var errorDescription: String?
    {
        switch self
        {
        case .invalidExamDate:
            return "考试日期格式看起来不太对，暂时没法添加到日历。"
        case .invalidExamTime:
            return "考试时间格式看起来不太对，暂时没法添加到日历。"
        }
    }
}

private extension String
{
    func firstMatch(of pattern: String) -> String?
    {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: self, range: NSRange(startIndex..., in: self)),
              let range = Range(match.range, in: self)
        else
        {
            return nil
        }

        return String(self[range])
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
    @Binding var querySource: ExamQuerySource

    @State private var showPicker = false
    @State private var showSourcePicker = false
    @EnvironmentObject var userinfo: userInfo

    let requestMFACode: MFACodeProvider
    let scheduleQuery: ScheduleQuery
    let examQuery: ExamQuery

    let years = ["2023", "2024", "2025", "2026"]
    let terms = [("第一学期", "1"), ("第二学期", "2")]

    var body: some View
    {
        HStack(spacing: 15)
        {
            Button(action: { showSourcePicker = true })
            {
                HStack(spacing: 6)
                {
                    Text(querySource.title)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .font(.system(size: 14, weight: .bold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.systemBackground).opacity(0.9))
                .clipShape(Capsule())
            }
            .optionalLiquidGlass()

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
                    ForEach(ExamQuerySource.allCases)
                    { source in
                        Button(action: {
                            switchSource(to: source)
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
        guard !userinfo.username.isEmpty else
        {
            alertTitle = "查询失败"
            alertMessage = "好像忘记了登录，请先去登录吧！"
            showAlert = true
            return
        }

        isLoading = true
        Task
        {
            do
            {
                let result: [Exam]
                switch querySource
                {
                case .cas:
                    let cookie = try await scheduleQuery.loginAndGetCookie(
                        username: userinfo.username,
                        rsaPassword: userinfo.encryptedPasswordSchool,
                        mfaCodeProvider: requestMFACode
                    )
                    result = try await examQuery.fetchExams(
                        cookie: cookie,
                        xnm: selectedYear,
                        xqm: selectedTerm == "1" ? "3" : "12"
                    )
                case .shishanyouni:
                    result = try await examQuery.fetchExamsFromShishanyouni(
                        username: userinfo.username,
                        encryptedPassword: userinfo.encryptedPasswordShishanyouni,
                        xnm: selectedYear,
                        xqm: selectedTerm
                    )
                }

                await MainActor.run
                {
                    AcademicQueryCache.save(
                        result,
                        namespace: "exam",
                        username: userinfo.username,
                        parts: [querySource.rawValue, selectedYear, selectedTerm]
                    )
                    self.exams = result
                    self.isLoading = false
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
