//
//  SchoolCalendarView.swift
//  shishanyouni
//
//  学校校历页面，只处理校历数据、同步和原文网页入口。
//

import SwiftUI
import WebKit

// MARK: - WebView 包装

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
        guard let url = URL(string: urlString) else { return }
        uiView.load(URLRequest(url: url))
    }
}

// MARK: - 学校校历页

struct SchoolCalendarView: View
{
    @EnvironmentObject var userinfo: userInfo

    @State private var currentMonth: Date
    @State private var selectedDate: Date
    @State private var schoolEvents: [SchoolCalendarEvent] = []
    @State private var isSyncing = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    @State private var showMFASheet = false
    @State private var mfaMaskedPhone = ""
    @State private var mfaCode = ""
    @State private var mfaContinuation: CheckedContinuation<String?, Never>?
    @State private var mfaSendCodeAction: (() async -> String?)?

    private let calendar = Calendar.current
    private let scheduleQuery = ScheduleQuery()
    private let calendarFetcher = SchoolCalendarFetcher.shared
    private let schoolCalendarURL = "https://open.work.weixin.qq.com/wwopen/mpnews?mixuin=lu0DCgAABwCtk1udAAAUAA&mfid=WW0313-r02y_AAABwD-jQWRBOWZ_Q52-zt98&idx=0&sn=d9818177ae6ac23d94424b331809cfd4"

    private var isGuestMode: Bool
    {
        userinfo.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init()
    {
        let now = Date()
        let monthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: now)) ?? now
        _currentMonth = State(initialValue: monthStart)
        _selectedDate = State(initialValue: Calendar.current.startOfDay(for: now))
    }

    var body: some View
    {
        VStack(spacing: 0)
        {
            monthSelector
                .padding(.horizontal)
                .padding(.vertical, 6)

            ScrollView
            {
                VStack(spacing: 16)
                {
                    CalendarMonthView(
                        month: currentMonth,
                        schoolEvents: schoolEvents,
                        personalEvents: [],
                        selectedDate: $selectedDate
                    )
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 12)
                    
                    schoolEventsForSelectedDateSection
                        .padding(.bottom, 20)
                    schoolCalendarWebSection
                }
                .padding(.top, 8)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("校历")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar
        {
            ToolbarItem(placement: .navigationBarTrailing)
            {
                Button
                {
                    syncSchoolCalendar()
                }
                label:
                {
                    if isSyncing
                    {
                        ProgressView().scaleEffect(0.8)
                    }
                    else
                    {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                }
                .disabled(isSyncing)
            }
        }
        .onAppear
        {
            schoolEvents = SchoolCalendarStore.shared.loadEvents()
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
        .alert("提示", isPresented: $showAlert)
        {
            Button("确定") {}
        }
        message:
        {
            Text(alertMessage)
        }
    }

    private var schoolCalendarWebSection: some View
    {
        NavigationLink
        {
            SchoolCalendarOriginalWebView(urlString: schoolCalendarURL)
        }
        label:
        {
            HStack(spacing: 14)
            {
                ZStack
                {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: 4)
                {
                    Text("查看校历原始内容")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color(.systemGray3))
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.orange.opacity(0.12), lineWidth: 1)
            )
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
    }

    private var monthSelector: some View
    {
        HStack
        {
            Button
            {
                withAnimation
                {
                    currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                }
            }
            label:
            {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                    .frame(width: 36, height: 36)
                    .background(Color.blue.opacity(0.1), in: Circle())
            }

            Spacer()

            Button
            {
                withAnimation
                {
                    selectedDate = Calendar.current.startOfDay(for: Date())
                    currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? currentMonth
                }
            }
            label:
            {
                Text("今天")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1), in: Capsule())
                    .foregroundColor(.blue)
            }

            Spacer()

            Button
            {
                withAnimation
                {
                    currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                }
            }
            label:
            {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                    .frame(width: 36, height: 36)
                    .background(Color.blue.opacity(0.1), in: Circle())
            }
        }
    }

    private var schoolEventsForSelectedDateSection: some View
    {
        VStack(alignment: .leading, spacing: 10)
        {
            HStack
            {
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

            if dayEvents.isEmpty
            {
                SchoolCalendarEmptyState(
                    systemImage: "calendar.badge.minus",
                    title: "当天无校历安排",
                    subtitle: "如果学校发布了新校历，可以点右上角同步。"
                )
            }
            else
            {
                ForEach(dayEvents)
                { event in
                    SchoolEventRow(event: event)
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    private var formattedSelectedDate: String
    {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "M月d日 EEEE"
        return fmt.string(from: selectedDate)
    }

    private func syncSchoolCalendar()
    {
        guard !isGuestMode else
        {
            alertMessage = "请先登录账号后再同步校历"
            showAlert = true
            return
        }

        isSyncing = true
        Task
        {
            do
            {
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
                    cookie: cookie,
                    xnm: currentXnm,
                    xqm: currentXqm
                )
                allEvents.append(contentsOf: fetched)

                if allEvents.isEmpty
                {
                    let prevXnm = currentMonth <= 7 ? String(currentYear - 2) : String(currentYear - 1)
                    let prevXqm = currentMonth <= 7 ? "3" : "12"
                    let prevFetched = try await calendarFetcher.fetchSchoolCalendar(
                        cookie: cookie,
                        xnm: prevXnm,
                        xqm: prevXqm
                    )
                    allEvents.append(contentsOf: prevFetched)
                }

                let merged = mergeFetchedSchoolEvents(allEvents)
                SchoolCalendarStore.shared.saveEvents(merged)

                await MainActor.run
                {
                    schoolEvents = merged
                    isSyncing = false
                    alertMessage = allEvents.isEmpty
                        ? "未从学校系统获取到校历数据，请确认学期设置"
                        : "成功同步 \(allEvents.count) 条校历信息"
                    showAlert = true
                }
            }
            catch
            {
                await MainActor.run
                {
                    isSyncing = false
                    alertMessage = "同步失败：\(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }

    private func mergeFetchedSchoolEvents(_ allEvents: [SchoolCalendarEvent]) -> [SchoolCalendarEvent]
    {
        var merged = SchoolCalendarStore.shared.loadEvents()
        var combinedEvents: [SchoolCalendarEvent] = []
        let sorted = allEvents.sorted { $0.startDate < $1.startDate }

        var i = 0
        while i < sorted.count
        {
            let current = sorted[i]
            var earliestStart = current.startDate
            var latestEnd = current.endDate ?? current.startDate
            var j = i

            while j + 1 < sorted.count
            {
                let next = sorted[j + 1]
                let nextStart = next.startDate
                let gap = calendar.dateComponents([.day], from: latestEnd, to: nextStart).day ?? 999
                if current.title == next.title && current.type == next.type && gap <= 30
                {
                    j += 1
                    if next.startDate < earliestStart { earliestStart = next.startDate }
                    if let end = next.endDate, end > latestEnd { latestEnd = end }
                    else if next.startDate > latestEnd { latestEnd = next.startDate }
                }
                else
                {
                    break
                }
            }

            combinedEvents.append(SchoolCalendarEvent(
                title: current.title,
                startDate: earliestStart,
                endDate: earliestStart == latestEnd ? nil : latestEnd,
                type: current.type,
                description: current.description
            ))
            i = j + 1
        }

        let fetchedTitles: [String: Set<SchoolEventType>] = {
            var dict: [String: Set<SchoolEventType>] = [:]
            for event in combinedEvents
            {
                dict[event.title, default: []].insert(event.type)
            }
            return dict
        }()

        merged.removeAll
        {
            if let types = fetchedTitles[$0.title], types.contains($0.type) { return true }
            return false
        }
        merged.append(contentsOf: combinedEvents)
        return merged
    }

    private func requestMFACode(maskedPhone: String?) async -> String?
    {
        await MainActor.run
        {
            mfaMaskedPhone = maskedPhone ?? ""
            mfaCode = ""
            mfaSendCodeAction = MFACodeContext.activeSendCodeAction
        }
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



private struct SchoolCalendarEmptyState: View
{
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View
    {
        VStack(spacing: 8)
        {
            Image(systemName: systemImage)
                .font(.system(size: 34))
                .foregroundColor(.secondary.opacity(0.5))
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(subtitle)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
    }
}

// MARK: - 校历事件行

struct SchoolEventRow: View
{
    let event: SchoolCalendarEvent

    var body: some View
    {
        HStack(spacing: 10)
        {
            ZStack
            {
                Circle()
                    .fill(event.type.typeColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: event.type.systemImage)
                    .font(.system(size: 14))
                    .foregroundColor(event.type.typeColor)
            }

            VStack(alignment: .leading, spacing: 2)
            {
                Text(event.title)
                    .font(.system(size: 14, weight: .medium))

                HStack(spacing: 6)
                {
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

// MARK: - 校历原文网页

struct SchoolCalendarOriginalWebView: View
{
    let urlString: String

    var body: some View
    {
        SchoolCalendarWeb(urlString: urlString)
            .background(Color(.systemBackground))
            .navigationTitle("校历原文")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
    }
}

// MARK: - 校历事件颜色

extension SchoolEventType
{
    var typeColor: Color
    {
        switch self
        {
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
#Preview("校历")
{
    NavigationStack
    {
        SchoolCalendarView()
            .environmentObject(userInfo())
    }
}
#endif
