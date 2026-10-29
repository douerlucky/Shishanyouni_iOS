import SwiftUI
import UIKit
import WebKit

// MARK: - 学校校历页

struct SchoolCalendarView: View
{
    @EnvironmentObject var userinfo: userInfo
    @AppStorage("enableLiquidGlassEffect") private var enableLiquidGlassEffect: Bool = false

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
    private let scheduleQuery = SchoolAcademicAPI()
    private let calendarFetcher = SchoolCalendarAPI.shared

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
                    .optionalLiquidGlass(
                        enabled: enableLiquidGlassEffect,
                        cornerRadius: 20,
                        fallback: Color(.secondarySystemGroupedBackground).opacity(0.72)
                    )
                    .padding(.horizontal, 12)
                    .monthSwipe { monthOffset in
                        moveMonth(by: monthOffset)
                    }
                    
                    schoolEventsForSelectedDateSection
                        .padding(.bottom, 20)
                    schoolCalendarWebSection
                }
                .padding(.top, 8)
            }
        }
        .background(Color.clear)
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
            SchoolCalendarOriginalWebView(urlString: SchoolDirectAPI.schoolCalendarArticleURL)
        }
        label:
        {
            HStack(spacing: 14)
            {
                ZStack
                {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.orange.opacity(0.12))
                        .componentBackgroundOpacity()
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
                        .appTextOpacity()
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color(.systemGray3))
            }
            .padding(16)
            .optionalLiquidGlass(
                enabled: enableLiquidGlassEffect,
                cornerRadius: 20,
                fallback: Color(.secondarySystemGroupedBackground).opacity(0.72)
            )
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
    }

    private var monthSelector: some View
    {
        MonthNavigationControls(
            tint: appActionBlue,
            onPrevious: {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation { currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth }
            },
            onToday: {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation
                {
                    selectedDate = calendar.startOfDay(for: Date())
                    currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? currentMonth
                }
            },
            onNext: {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation { currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth }
            }
        )
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

    private func moveMonth(by offset: Int)
    {
        guard let month = calendar.date(byAdding: .month, value: offset, to: currentMonth)
        else { return }

        let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: month)
        ) ?? month
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 28
        let day = min(calendar.component(.day, from: selectedDate), daysInMonth)
        var components = calendar.dateComponents([.year, .month], from: monthStart)
        components.day = day

        withAnimation(.easeInOut(duration: 0.28))
        {
            currentMonth = monthStart
            selectedDate = calendar.startOfDay(for: calendar.date(from: components) ?? monthStart)
        }
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

                let fetched = try await calendarFetcher.fetchSchoolCalendar(cookie: cookie)

                // 学校页面是唯一可信来源；成功同步后直接替换旧的估算/缓存活动。
                SchoolCalendarStore.shared.saveEvents(fetched)

                await MainActor.run
                {
                    schoolEvents = fetched
                    isSyncing = false
                    alertMessage = "成功同步 \(fetched.count) 条校历信息"
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
