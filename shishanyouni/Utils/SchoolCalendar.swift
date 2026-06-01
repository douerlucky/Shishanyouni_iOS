//
//  SchoolCalendar.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/16.
//

import SwiftUI
import WebKit

// 使用 UIViewRepresentable 包装 WKWebView（GIS等模块复用）
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

// MARK: - 新版校历（日历视图 + 行程融合）

struct SchoolCalendarView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var iapStore: IAPStore
    
    @State private var currentMonth: Date
    @State private var selectedDate: Date
    @State private var schoolEvents: [SchoolCalendarEvent] = []
    @State private var personalEvents: [Event] = []
    @State private var showingEventDetail = false
    @State private var showingAddEvent = false
    
    private let calendar = Calendar.current
    
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
                .padding(.vertical, 8)
            
            ScrollView {
                VStack(spacing: 0) {
                    CalendarMonthView(
                        month: currentMonth,
                        schoolEvents: schoolEvents,
                        personalEvents: iapStore.hasActiveSubscription ? personalEvents : [],
                        selectedDate: $selectedDate
                    )
                    .padding(.horizontal, 12)
                    
                    Divider()
                        .padding(.vertical, 12)
                    
                    selectedDateEventsSection
                    
                    if iapStore.hasActiveSubscription {
                        personalEventsOnDateSection
                    }
                    
                    if !iapStore.hasActiveSubscription {
                        iapTeaserSection
                    }
                    
                    Divider()
                        .padding(.vertical, 12)
                    
                    webViewSection
                }
            }
            
            if iapStore.hasActiveSubscription {
                addEventButton
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("校历")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            schoolEvents = SchoolCalendarStore.shared.loadEvents()
            personalEvents = EventStore.shared.loadEvents()
        }
        .onChange(of: selectedDate) { _ in
            personalEvents = EventStore.shared.loadEvents()
        }
        .sheet(isPresented: $navigateToSubscription) {
            SubscriptionView()
        }
        .sheet(isPresented: $showingAddEvent) {
            EventEditView(events: $personalEvents, mode: .add)
        }
        .onChange(of: showingAddEvent) { newValue in
            if !newValue {
                personalEvents = EventStore.shared.loadEvents()
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
        .padding(.vertical, 4)
    }
    
    // MARK: - 选中日期的校历事件
    
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
    
    // MARK: - 选中日期的个人行程
    
    private var personalEventsOnDateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("我的行程")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.1), in: Capsule())
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            let dayInstances = personalEvents.flatMap { $0.instances(in: selectedDate...selectedDate) }
            
            if dayInstances.isEmpty {
                HStack {
                    Image(systemName: "calendar.badge.plus")
                        .foregroundColor(.secondary)
                    Text("暂无个人行程，点击下方按钮添加")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
            } else {
                ForEach(dayInstances) { event in
                    PersonalEventCalendarRow(event: event)
                        .padding(.horizontal, 16)
                }
            }
        }
    }
    
    // MARK: - IAP 引导
    
    private var iapTeaserSection: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.top, 12)
            
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.caption)
                Text("开通校园通行证，即可在日历中查看和管理你的私人行程")
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
    
    // MARK: - 辅助
    
    // MARK: - 原文网页
    
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
    
    private var formattedSelectedDate: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "M月d日 EEEE"
        return fmt.string(from: selectedDate)
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

// MARK: - 个人行程日历行

struct PersonalEventCalendarRow: View {
    let event: Event
    
    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(event.displayColor)
                .frame(width: 4, height: 36)
            
            Image(systemName: event.category.systemImage)
                .font(.system(size: 12))
                .foregroundColor(event.category.defaultColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 14, weight: .medium))
                    .strikethrough(event.isCompleted, color: .gray)
                    .foregroundColor(event.isCompleted ? .gray : .primary)
                
                HStack(spacing: 6) {
                    if let timeText = event.formattedTime() {
                        Text(timeText)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    if event.isAllDay {
                        Text("全天")
                            .font(.system(size: 10))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(3)
                    }
                    
                    if let loc = event.location, !loc.isEmpty {
                        Text(loc)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
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

#Preview
{
    NavigationStack {
        SchoolCalendarView()
            .environmentObject(IAPStore(autoload: false))
    }
}
