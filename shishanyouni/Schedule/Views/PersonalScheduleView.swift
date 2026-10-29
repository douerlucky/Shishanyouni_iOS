import SwiftUI
import UIKit

// MARK: - 个人日程 Tab

struct PersonalScheduleView: View
{
    @EnvironmentObject var iapStore: IAPStore
    @AppStorage("enableLiquidGlassEffect") private var enableLiquidGlassEffect: Bool = false

    @State private var currentMonth: Date
    @State private var selectedDate: Date
    @State private var personalEvents: [Event] = []
    @State private var completions: [String: Bool] = [:]
    @State private var refreshToggle = false
    @State private var showingAddEvent = false
    @State private var editingEvent: Event?
    @State private var quickAddText = ""
    @State private var filter: PersonalEventFilter = .all
    @State private var navigateToSubscription = false

    private let calendar = Calendar.current

    private var isSubscribed: Bool
    {
        iapStore.hasActiveSubscription
    }

    private var dateRange: ClosedRange<Date>
    {
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 30, to: start)!
        return start...end
    }

    private var selectedDateRange: ClosedRange<Date>
    {
        let start = calendar.startOfDay(for: selectedDate)
        let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? start
        return start...end
    }

    private var filteredPersonalInstances: [Event]
    {
        let instances = personalEvents
            .flatMap { $0.instances(in: dateRange) }
            .sorted
            { lhs, rhs in
                return lhs.date < rhs.date
            }

        switch filter
        {
        case .all: return instances
        case .today: return instances.filter { calendar.isDateInToday($0.date) }
        case .thisWeek: return instances.filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear) }
        case .todo: return instances.filter { $0.category == .todo }
        case .incomplete: return instances.filter { !$0.isCompleted }
        }
    }

    private var selectedDatePersonalEvents: [Event]
    {
        personalEvents
            .flatMap { $0.instances(in: selectedDateRange) }
            .sorted { $0.date < $1.date }
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
        ZStack(alignment: .bottom)
        {
            VStack(spacing: 0)
            {
                monthSelector
                    .padding(.horizontal)
                    .padding(.vertical, 6)

                if isSubscribed
                {
                    quickAddBar
                }

                ScrollView
                {
                    VStack(spacing: 16)
                    {
                        CalendarMonthView(
                            month: currentMonth,
                            schoolEvents: [],
                            personalEvents: isSubscribed ? personalEvents : [],
                            selectedDate: $selectedDate
                        )
                        .padding(16)
                        .optionalLiquidGlass(
                            enabled: enableLiquidGlassEffect,
                            cornerRadius: 20,
                            fallback: Color(.secondarySystemGroupedBackground).opacity(0.88)
                        )
                        .padding(.horizontal, 12)
                        .monthSwipe { monthOffset in
                            moveMonth(by: monthOffset)
                        }

                        if isSubscribed
                        {
                            selectedDatePersonalEventsSection
                            personalEventsFilter
                            personalEventsListSection
                        }
                        else
                        {
                            iapTeaserSection
                                .padding(.top, 8)
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, isSubscribed ? 180 : 24)
                }
            }

            if isSubscribed
            {
                addEventButton
                    .padding(.bottom, 96)
            }
        }
        .background(Color.clear)
        .onAppear
        {
            loadEventData()
        }
        .onChange(of: selectedDate)
        { _ in
            loadEventData()
        }
        .sheet(isPresented: $navigateToSubscription)
        {
            SubscriptionView()
        }
        .sheet(isPresented: $showingAddEvent)
        {
            EventEditView(events: $personalEvents, mode: .add)
        }
        .sheet(item: $editingEvent)
        { event in
            EventEditView(events: $personalEvents, mode: .edit(event))
        }
        .onChange(of: showingAddEvent)
        { newValue in
            if !newValue { loadEventData() }
        }
        .onChange(of: editingEvent)
        { newValue in
            if newValue == nil { loadEventData() }
        }
    }

    private var monthSelector: some View
    {
        MonthNavigationControls(
            tint: .purple,
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

    private var quickAddBar: some View
    {
        HStack(spacing: 8)
        {
            Image(systemName: "plus.circle.fill")
                .foregroundColor(.purple)
                .font(.title3)

            TextField("快速添加待办，按回车确认...", text: $quickAddText)
                .font(.subheadline)
                .appTextOpacity()
                .onSubmit { addQuickTodo() }

            if !quickAddText.isEmpty
            {
                NextButton(systemImage: "arrow.up", tint: .purple, action: addQuickTodo)
                    .accessibilityLabel("添加待办")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .optionalLiquidGlass(
            enabled: enableLiquidGlassEffect,
            cornerRadius: 16,
            fallback: Color(.secondarySystemBackground).opacity(0.82)
        )
        .padding(.horizontal, 12)
    }

    private var selectedDatePersonalEventsSection: some View
    {
        VStack(alignment: .leading, spacing: 10)
        {
            HStack
            {
                Text(formattedSelectedDate)
                    .font(.system(size: 16, weight: .semibold))
                    .appTextOpacity()

                Spacer()

                Text("当天日程")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .appTextOpacity()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background
                    {
                        Capsule().fill(Color.purple.opacity(0.1))
                            .componentBackgroundOpacity()
                    }
            }
            .padding(.horizontal, 16)

            if selectedDatePersonalEvents.isEmpty
            {
                ScheduleEmptyState(
                    systemImage: "calendar.badge.plus",
                    title: "当天暂无日程",
                    subtitle: "可以使用快速添加，或点击底部按钮创建新行程。"
                )
            }
            else
            {
                ForEach(selectedDatePersonalEvents)
                { event in
                    PersonalEventRow(
                        event: event,
                        completed: bindingForEvent(event)
                    )
                    .id("selected_\(event.id)_\(refreshToggle)")
                    .padding(.horizontal, 16)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true)
                    {
                        Button(role: .destructive)
                        {
                            deleteEvent(event)
                        }
                        label:
                        {
                            Label("删除", systemImage: "trash")
                        }
                        Button
                        {
                            editingEvent = event
                        }
                        label:
                        {
                            Label("编辑", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .contextMenu
                    {
                        Button
                        {
                            editingEvent = event
                        }
                        label:
                        {
                            Label("编辑", systemImage: "pencil")
                        }
                        Button(role: .destructive)
                        {
                            deleteEvent(event)
                        }
                        label:
                        {
                            Label("删除", systemImage: "trash")
                        }
                    } preview: {
                        EventContextPreview(event: event, completed: bindingForEvent(event).wrappedValue)
                    }
                }
            }
        }
    }

    private var personalEventsFilter: some View
    {
        HStack(spacing: 8)
        {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.caption)
                .foregroundColor(.secondary)

            Picker("筛选", selection: $filter)
            {
                ForEach(PersonalEventFilter.allCases, id: \.self)
                { filter in
                    Label(filter.rawValue, systemImage: filter.systemImage).tag(filter)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 16)
    }

    private var personalEventsListSection: some View
    {
        VStack(alignment: .leading, spacing: 8)
        {
            HStack
            {
                Text("近期日程")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Text("未来30天")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)

            let grouped = groupedPersonalEvents

            if filteredPersonalInstances.isEmpty
            {
                ScheduleEmptyState(
                    systemImage: "tray",
                    title: "暂无匹配日程",
                    subtitle: "换个筛选条件，或者添加新的待办/行程。"
                )
            }
            else
            {
                ForEach(grouped.keys.sorted(), id: \.self)
                { dateKey in
                    SectionHeader(dateKey: dateKey, count: grouped[dateKey]?.count ?? 0)

                    ForEach(grouped[dateKey] ?? [])
                    { event in
                        PersonalEventRow(
                            event: event,
                            completed: bindingForEvent(event)
                        )
                        .id("list_\(event.id)_\(refreshToggle)")
                        .padding(.horizontal, 16)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true)
                        {
                            Button(role: .destructive)
                            {
                                deleteEvent(event)
                            }
                            label:
                            {
                                Label("删除", systemImage: "trash")
                            }
                            Button
                            {
                                editingEvent = event
                            }
                            label:
                            {
                                Label("编辑", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        .contextMenu
                        {
                            Button
                            {
                                editingEvent = event
                            }
                            label:
                            {
                                Label("编辑", systemImage: "pencil")
                            }
                            Button(role: .destructive)
                            {
                                deleteEvent(event)
                            }
                            label:
                            {
                                Label("删除", systemImage: "trash")
                            }
                        } preview: {
                            EventContextPreview(event: event, completed: bindingForEvent(event).wrappedValue)
                        }
                    }
                }
            }
        }
    }

    private var iapTeaserSection: some View
    {
        VStack(spacing: 12)
        {
            HStack(spacing: 8)
            {
                Image(systemName: "lock.fill")
                    .font(.caption)
                Text("开通校园通行证，即可管理你的私人行程、待办与备忘")
                    .font(.subheadline)
                    .appTextOpacity()
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)

            LiquidGlassCapsuleButton(title: "了解校园通行证", tint: .purple)
            {
                navigateToSubscription = true
            }
            .padding(.horizontal, 16)
        }
    }

    private var addEventButton: some View
    {
        Button
        {
            showingAddEvent = true
        }
        label:
        {
            Label("添加日程", systemImage: "plus")
                .labelStyle(TextOpacityLabelStyle())
                .font(.headline)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .nativeGlassButtonStyle(prominent: true, fillsWidth: true, backgroundTint: .purple)
        .tint(.purple)
        .controlSize(.large)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var groupedPersonalEvents: [String: [Event]]
    {
        Dictionary(grouping: filteredPersonalInstances) { $0.formattedDate() }
    }

    private var formattedSelectedDate: String
    {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "M月d日 EEEE"
        return fmt.string(from: selectedDate)
    }

    private func loadEventData()
    {
        personalEvents = EventStore.shared.loadEvents()
        completions = EventStore.shared.getAllCompletions()
    }

    private func addQuickTodo()
    {
        let trimmed = quickAddText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let newEvent = Event(
            title: trimmed,
            date: selectedDate,
            category: .todo
        )
        personalEvents.append(newEvent)
        EventStore.shared.saveEvents(personalEvents)
        quickAddText = ""
    }

    private func deleteEvent(_ event: Event)
    {
        personalEvents.removeAll { $0.id == event.id }
        EventStore.shared.removeCompletions(for: event.id)
        EventStore.shared.saveEvents(personalEvents)
    }

    private func bindingForEvent(_ event: Event) -> Binding<Bool>
    {
        Binding(
            get: {
                EventStore.shared.isCompleted(eventId: event.id, date: event.date)
            },
            set: { newValue in
                if let index = personalEvents.firstIndex(where: { $0.id == event.id }), personalEvents[index].repeatRule == nil
                {
                    personalEvents[index].isCompleted = newValue
                    EventStore.shared.saveEvents(personalEvents)
                }
                EventStore.shared.setCompletion(eventId: event.id, date: event.date, completed: newValue)
                var newCompletions = completions
                newCompletions[EventStore.shared.completionKey(for: event.id, date: event.date)] = newValue
                completions = newCompletions
                refreshToggle.toggle()
            }
        )
    }
}
