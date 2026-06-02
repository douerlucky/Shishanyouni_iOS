//
//  SchoolCalendar.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/16.
//  整合版：校历日历 + 校历事件 + 个人行程全功能管理
//

import SwiftUI
import WebKit

// MARK: - WebView 包装（校历原文）

struct SchoolCalendarWeb: UIViewRepresentable
{
    let urlString: String

    func makeUIView(context: Context) -> WKWebView
    {
        let webView = WKWebView()
        webView.allowsBackForwardNavigationGestures = true
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context)
    {
        if let url = URL(string: urlString)
        {
            let request = URLRequest(url: url)
            uiView.load(request)
        }
    }
}

// MARK: - 查看模式

private enum CalendarViewMode: String, CaseIterable {
    case schedule = "校历"
    case personal = "行程"

    var systemImage: String {
        switch self {
        case .schedule: return "building.columns"
        case .personal: return "checklist"
        }
    }
}

// MARK: - 行程筛选

private enum PersonalEventFilter: String, CaseIterable {
    case today = "今天"
    case thisWeek = "本周"
    case all = "全部"
    case todo = "待办"
    case incomplete = "未完成"

    var systemImage: String {
        switch self {
        case .today: return "sun.max"
        case .thisWeek: return "calendar.badge.clock"
        case .all: return "list.bullet"
        case .todo: return "checklist"
        case .incomplete: return "circle"
        }
    }
}

// MARK: - 新版校历（日历视图 + 行程融合）

struct SchoolCalendarView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var iapStore: IAPStore
    @EnvironmentObject var userinfo: userInfo

    // 日历状态
    @State private var currentMonth: Date
    @State private var selectedDate: Date
    @State private var schoolEvents: [SchoolCalendarEvent] = []
    @State private var personalEvents: [Event] = []
    @State private var completions: [String: Bool] = [:]
    @State private var refreshToggle = false
    @State private var isSyncing = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    // 个人行程管理状态
    @State private var showingAddEvent = false
    @State private var editingEvent: Event?
    @State private var quickAddText: String = ""
    @State private var filter: PersonalEventFilter = .all
    @State private var countdownItems: [CountdownItem] = []

    // MFA
    @State private var showMFASheet = false
    @State private var mfaMaskedPhone = ""
    @State private var mfaCode = ""
    @State private var mfaContinuation: CheckedContinuation<String?, Never>?
    @State private var mfaSendCodeAction: (() async -> String?)?

    private let calendar = Calendar.current
    private let scheduleQuery = ScheduleQuery()
    private let calendarFetcher = SchoolCalendarFetcher.shared

    private var isGuestMode: Bool {
        userinfo.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isSubscribed: Bool {
        iapStore.hasActiveSubscription
    }

    private var dateRange: ClosedRange<Date> {
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 30, to: start)!
        return start...end
    }

    private var filteredPersonalInstances: [Event] {
        let instances = personalEvents
            .flatMap { $0.instances(in: dateRange) }
            .sorted { a, b in
                if a.isOverdue != b.isOverdue { return a.isOverdue }
                if a.priority.sortOrder != b.priority.sortOrder { return a.priority.sortOrder < b.priority.sortOrder }
                return a.date < b.date
            }

        switch filter {
        case .all: return instances
        case .today: return instances.filter { calendar.isDateInToday($0.date) }
        case .thisWeek: return instances.filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear) }
        case .todo: return instances.filter { $0.category == .todo }
        case .incomplete: return instances.filter { !$0.isCompleted }
        }
    }

    init() {
        let now = Date()
        let monthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: now)) ?? now
        _currentMonth = State(initialValue: monthStart)
        _selectedDate = State(initialValue: Calendar.current.startOfDay(for: now))
    }

    var body: some View {
        VStack(spacing: 0) {
            monthSelector
                .padding(.horizontal)
                .padding(.vertical, 6)

            if isSubscribed {
                quickAddBar
            }

            ScrollView {
                VStack(spacing: 0) {
                    CalendarMonthView(
                        month: currentMonth,
                        schoolEvents: schoolEvents,
                        personalEvents: isSubscribed ? personalEvents : [],
                        selectedDate: $selectedDate
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)

                    Divider()
                        .padding(.vertical, 12)

                    if isSubscribed {
                        countdownSection
                        personalEventsFilter
                        personalEventsListSection
                    } else {
                        iapTeaserSection
                    }

                    Divider()
                        .padding(.vertical, 12)

                    selectedDateEventsSection

                    Divider()
                        .padding(.vertical, 12)

                    webViewSection
                }
            }

            if isSubscribed {
                addEventButton
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("日程与校历")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    syncSchoolCalendar()
                } label: {
                    if isSyncing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                }
                .disabled(isSyncing)
            }
        }
        .onAppear {
            loadAllData()
        }
        .onChange(of: selectedDate) { _ in
            personalEvents = EventStore.shared.loadEvents()
            completions = EventStore.shared.getAllCompletions()
        }
        .sheet(isPresented: $navigateToSubscription) {
            SubscriptionView()
        }
        .sheet(isPresented: $showingAddEvent) {
            EventEditView(events: $personalEvents, mode: .add)
        }
        .sheet(item: $editingEvent) { event in
            EventEditView(events: $personalEvents, mode: .edit(event))
        }
        .sheet(isPresented: $showMFASheet) {
            MFACodeInputSheet(
                maskedPhone: mfaMaskedPhone,
                code: $mfaCode,
                onSendCode: $mfaSendCodeAction,
                onCancel: { resolveMFACode(nil) },
                onConfirm: { resolveMFACode(mfaCode.trimmingCharacters(in: .whitespacesAndNewlines)) }
            )
        }
        .alert("提示", isPresented: $showAlert) {
            Button("确定") {}
        } message: {
            Text(alertMessage)
        }
        .onChange(of: showingAddEvent) { newValue in
            if !newValue {
                personalEvents = EventStore.shared.loadEvents()
            }
        }
        .onChange(of: editingEvent) { newValue in
            if newValue == nil {
                personalEvents = EventStore.shared.loadEvents()
                completions = EventStore.shared.getAllCompletions()
            }
        }
    }

    // MARK: - 月份选择器

    private var monthSelector: some View {
        HStack {
            Button {
                withAnimation {
                    currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                    .frame(width: 36, height: 36)
                    .background(Color.blue.opacity(0.1), in: Circle())
            }

            Spacer()

            Button {
                withAnimation {
                    selectedDate = Date()
                    currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? currentMonth
                }
            } label: {
                Text("今天")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1), in: Capsule())
                    .foregroundColor(.blue)
            }

            Spacer()

            Button {
                withAnimation {
                    currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                    .frame(width: 36, height: 36)
                    .background(Color.blue.opacity(0.1), in: Circle())
            }
        }
    }

    // MARK: - 快速添加

    private var quickAddBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .foregroundColor(.purple)
                .font(.title3)

            TextField("快速添加待办，按回车确认...", text: $quickAddText)
                .font(.subheadline)
                .onSubmit { addQuickTodo() }

            if !quickAddText.isEmpty {
                Button {
                    addQuickTodo()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.purple)
                        .font(.title3)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground).opacity(0.5))
    }

    // MARK: - 倒计时

    private var countdownSection: some View {
        Group {
            if !countdownItems.isEmpty {
                ScheduleCountdownView(items: countdownItems)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
        }
    }

    // MARK: - 行程筛选

    private var personalEventsFilter: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.caption)
                .foregroundColor(.secondary)

            Picker("筛选", selection: $filter) {
                ForEach(PersonalEventFilter.allCases, id: \.self) { f in
                    Label(f.rawValue, systemImage: f.systemImage).tag(f)
                }
            }
            .pickerStyle(.segmented)

            if hasCompletedItems {
                Button(role: .destructive) {
                    clearCompleted()
                } label: {
                    Text("清理")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.leading, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - 个人行程列表

    private var personalEventsListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            let grouped = groupedPersonalEvents

            if filteredPersonalInstances.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("暂无行程")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("使用上方快速添加或底部按钮创建新行程")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                ForEach(grouped.keys.sorted(), id: \.self) { dateKey in
                    SectionHeader(dateKey: dateKey, count: grouped[dateKey]?.count ?? 0)

                    ForEach(grouped[dateKey] ?? []) { event in
                        PersonalEventRow(
                            event: event,
                            completed: bindingForEvent(event)
                        )
                        .id("\(event.id)_\(refreshToggle)")
                        .padding(.horizontal, 16)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteEvent(event)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                            Button {
                                editingEvent = event
                            } label: {
                                Label("编辑", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 选中日期校历事件

    private var selectedDateEventsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(formattedSelectedDate)
                    .font(.system(size: 16, weight: .semibold))

                Spacer()

                Text("校历事件")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.1), in: Capsule())
            }
            .padding(.horizontal, 16)

            let dayEvents = schoolEvents.filter { $0.contains(date: selectedDate) }

            if dayEvents.isEmpty {
                HStack {
                    Image(systemName: "calendar.badge.minus")
                        .foregroundColor(.secondary)
                    Text("当天无校历安排")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
            } else {
                ForEach(dayEvents) { event in
                    SchoolEventRow(event: event)
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - IAP 引导

    private var iapTeaserSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.caption)
                Text("开通校园通行证，即可在校历中管理你的私人行程、待办与备忘")
                    .font(.subheadline)
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)

            Button {
                navigateToSubscription = true
            } label: {
                Text("了解校园通行证")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 16)
        }
    }

    @State private var navigateToSubscription = false

    // MARK: - 底部添加按钮

    private var addEventButton: some View {
        HStack {
            Button {
                showingAddEvent = true
            } label: {
                Label("添加行程", systemImage: "plus.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.purple, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - 校历原文网页

    private var webViewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("校历原文（网页版）")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)

            SchoolCalendarWeb(urlString: schoolCalendarURL)
                .frame(height: 600)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 12)
        }
    }

    private let schoolCalendarURL = "https://open.work.weixin.qq.com/wwopen/mpnews?mixuin=lu0DCgAABwCtk1udAAAUAA&mfid=WW0313-r02y_AAABwD-jQWRBOWZ_Q52-zt98&idx=0&sn=d9818177ae6ac23d94424b331809cfd4"

    // MARK: - 数据相关

    private var groupedPersonalEvents: [String: [Event]] {
        Dictionary(grouping: filteredPersonalInstances) { $0.formattedDate() }
    }

    private var hasCompletedItems: Bool {
        filteredPersonalInstances.contains { $0.isCompleted && $0.category == .todo }
    }

    private func loadAllData() {
        schoolEvents = SchoolCalendarStore.shared.loadEvents()
        personalEvents = EventStore.shared.loadEvents()
        completions = EventStore.shared.getAllCompletions()
        countdownItems = ScheduleCountdownView.buildCountdownItems()
    }

    private func addQuickTodo() {
        let trimmed = quickAddText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let newEvent = Event(
            title: trimmed,
            date: Date(),
            category: .todo,
            priority: .medium
        )
        personalEvents.append(newEvent)
        EventStore.shared.saveEvents(personalEvents)
        quickAddText = ""
    }

    private func deleteEvent(_ event: Event) {
        personalEvents.removeAll { $0.id == event.id }
        EventStore.shared.removeCompletions(for: event.id)
        EventStore.shared.saveEvents(personalEvents)
    }

    private func clearCompleted() {
        let idsToRemove = personalEvents.filter { $0.isCompleted && $0.category == .todo }.map(\.id)
        personalEvents.removeAll { idsToRemove.contains($0.id) }
        EventStore.shared.saveEvents(personalEvents)
    }

    private func bindingForEvent(_ event: Event) -> Binding<Bool> {
        Binding(
            get: {
                EventStore.shared.isCompleted(eventId: event.id, date: event.date)
            },
            set: { newValue in
                EventStore.shared.setCompletion(eventId: event.id, date: event.date, completed: newValue)
                var newCompletions = completions
                newCompletions[EventStore.shared.completionKey(for: event.id, date: event.date)] = newValue
                completions = newCompletions
                refreshToggle.toggle()
            }
        )
    }

    private var formattedSelectedDate: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "M月d日 EEEE"
        return fmt.string(from: selectedDate)
    }

    // MARK: - 同步校历

    private func syncSchoolCalendar() {
        guard !isGuestMode else {
            alertMessage = "请先登录账号后再同步校历"
            showAlert = true
            return
        }

        isSyncing = true
        Task {
            do {
                let cookie = try await scheduleQuery.loginAndGetCookie(
                    username: userinfo.username,
                    rsaPassword: userinfo.encryptedPasswordSchool,
                    mfaCodeProvider: requestMFACode
                )

                let currentYear = calendar.component(.year, from: Date())
                let currentMonth = calendar.component(.month, from: Date())

                let currentXnm = String(currentMonth <= 7 ? currentYear - 1 : currentYear)
                let currentXqm = currentMonth <= 7 ? "12" : "3"

                var allEvents: [SchoolCalendarEvent] = []

                let fetched = try await calendarFetcher.fetchSchoolCalendar(
                    cookie: cookie, xnm: currentXnm, xqm: currentXqm
                )
                allEvents.append(contentsOf: fetched)

                if allEvents.isEmpty {
                    let prevXnm = currentMonth <= 7 ? String(currentYear - 2) : String(currentYear - 1)
                    let prevXqm = currentMonth <= 7 ? "3" : "12"
                    let prevFetched = try await calendarFetcher.fetchSchoolCalendar(
                        cookie: cookie, xnm: prevXnm, xqm: prevXqm
                    )
                    allEvents.append(contentsOf: prevFetched)
                }

                var merged = SchoolCalendarStore.shared.loadEvents()

                var combinedEvents: [SchoolCalendarEvent] = []
                let sorted = allEvents.sorted { $0.startDate < $1.startDate }

                var i = 0
                while i < sorted.count {
                    let current = sorted[i]
                    var earliestStart = current.startDate
                    var latestEnd = current.endDate ?? current.startDate
                    var j = i

                    while j + 1 < sorted.count {
                        let next = sorted[j + 1]
                        let nextStart = next.startDate
                        let gap = calendar.dateComponents([.day], from: latestEnd, to: nextStart).day ?? 999
                        if current.title == next.title && current.type == next.type && gap <= 30 {
                            j += 1
                            if next.startDate < earliestStart { earliestStart = next.startDate }
                            if let end = next.endDate, end > latestEnd { latestEnd = end }
                            else if next.startDate > latestEnd { latestEnd = next.startDate }
                        } else {
                            break
                        }
                    }

                    let mergedEvent = SchoolCalendarEvent(
                        title: current.title,
                        startDate: earliestStart,
                        endDate: earliestStart == latestEnd ? nil : latestEnd,
                        type: current.type,
                        description: current.description
                    )
                    combinedEvents.append(mergedEvent)
                    i = j + 1
                }

                let fetchedTitles: [String: Set<SchoolEventType>] = {
                    var dict: [String: Set<SchoolEventType>] = [:]
                    for e in combinedEvents {
                        dict[e.title, default: []].insert(e.type)
                    }
                    return dict
                }()
                merged.removeAll {
                    if let types = fetchedTitles[$0.title], types.contains($0.type) { return true }
                    return false
                }

                merged.append(contentsOf: combinedEvents)

                SchoolCalendarStore.shared.saveEvents(merged)

                await MainActor.run {
                    schoolEvents = merged
                    isSyncing = false
                    alertMessage = allEvents.isEmpty
                        ? "未从学校系统获取到校历数据，请确认学期设置"
                        : "成功同步 \(allEvents.count) 条校历信息"
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    isSyncing = false
                    alertMessage = "同步失败：\(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }

    private func requestMFACode(maskedPhone: String?) async -> String? {
        await MainActor.run {
            mfaMaskedPhone = maskedPhone ?? ""
            mfaCode = ""
            mfaSendCodeAction = MFACodeContext.activeSendCodeAction
        }
        await Task.yield()
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
        mfaSendCodeAction = nil
    }
}

// MARK: - 分组标题

private struct SectionHeader: View {
    let dateKey: String
    let count: Int

    var body: some View {
        HStack {
            Text(dateKey)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)

            Text("\(count)项")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(.systemGray5), in: Capsule())

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }
}

// MARK: - 个人行程行

private struct PersonalEventRow: View {
    let event: Event
    @Binding var completed: Bool

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(event.isOverdue ? Color.red : event.displayColor)
                .frame(width: 4, height: 42)

            Button {
                completed.toggle()
            } label: {
                Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(completed ? .green : (event.isOverdue ? .red : .gray))
                    .font(.title3)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    if event.priority == .high {
                        Image(systemName: "exclamationmark.3")
                            .font(.system(size: 9))
                            .foregroundColor(.red)
                    }
                    Text(event.title)
                        .font(.system(size: 14, weight: .medium))
                        .strikethrough(completed, color: .gray)
                        .foregroundColor(completed ? .gray : (event.isOverdue ? .red : .primary))
                }

                HStack(spacing: 5) {
                    if let timeText = event.formattedTime() {
                        Text(timeText)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    if event.isAllDay {
                        Text("全天")
                            .font(.system(size: 10))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(3)
                    }
                    HStack(spacing: 2) {
                        Image(systemName: event.category.systemImage)
                            .font(.system(size: 8))
                        Text(event.category.rawValue)
                    }
                    .font(.system(size: 10))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(event.category.defaultColor.opacity(0.1))
                    .foregroundColor(event.category.defaultColor)
                    .cornerRadius(3)

                    if event.isOverdue {
                        Text("已过期")
                            .font(.system(size: 10))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(3)
                    }

                    let p = event.subtaskProgress
                    if p.total > 0 {
                        Text("\(p.done)/\(p.total)")
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(3)
                    }
                }

                if let due = event.dueDate {
                    HStack(spacing: 2) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 9))
                        Text(relativeDueText(for: due))
                            .font(.system(size: 10))
                            .foregroundColor(dueDateColor(for: due))
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private func relativeDueText(for date: Date) -> String {
        let today = Calendar.current.startOfDay(for: Date())
        let dueDay = Calendar.current.startOfDay(for: date)
        let days = Calendar.current.dateComponents([.day], from: today, to: dueDay).day ?? 0
        switch days {
        case ..<0: return "已过期\(-days)天"
        case 0: return "今天截止"
        case 1: return "明天截止"
        case 2: return "后天截止"
        case 3...7: return "\(days)天后截止"
        default:
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "zh_CN")
            fmt.dateFormat = "M月d日截止"
            return fmt.string(from: date)
        }
    }

    private func dueDateColor(for date: Date) -> Color {
        let today = Calendar.current.startOfDay(for: Date())
        let dueDay = Calendar.current.startOfDay(for: date)
        let days = Calendar.current.dateComponents([.day], from: today, to: dueDay).day ?? 0
        switch days {
        case ..<0: return .red
        case 0: return .red
        case 1...2: return .orange
        default: return .secondary
        }
    }
}

// MARK: - 校历事件行

struct SchoolEventRow: View {
    let event: SchoolCalendarEvent

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(event.type.typeColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: event.type.systemImage)
                    .font(.system(size: 14))
                    .foregroundColor(event.type.typeColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 14, weight: .medium))

                HStack(spacing: 6) {
                    Text(event.formattedDateRange())
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Text(event.type.rawValue)
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(event.type.typeColor.opacity(0.1))
                        .foregroundColor(event.type.typeColor)
                        .cornerRadius(3)
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - 校历事件颜色

extension SchoolEventType {
    var typeColor: Color {
        switch self {
        case .holiday: return .orange
        case .exam: return .red
        case .trimesterStart: return .green
        case .trimesterEnd: return .blue
        case .activity: return .purple
        case .other: return .gray
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        SchoolCalendarView()
            .environmentObject(IAPStore(autoload: false))
    }
}
#endif
