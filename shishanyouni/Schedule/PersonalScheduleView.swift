//
//  PersonalScheduleView.swift
//  shishanyouni
//
//  个人日程页面，只处理用户自己的待办、行程和备忘。
//

import SwiftUI

// MARK: - 行程筛选

private enum PersonalEventFilter: String, CaseIterable
{
    case today = "今天"
    case thisWeek = "本周"
    case all = "全部"
    case todo = "待办"
    case incomplete = "未完成"

    var systemImage: String
    {
        switch self
        {
        case .today: return "sun.max"
        case .thisWeek: return "calendar.badge.clock"
        case .all: return "list.bullet"
        case .todo: return "checklist"
        case .incomplete: return "circle"
        }
    }
}

// MARK: - 个人日程 Tab

struct PersonalScheduleView: View
{
    @EnvironmentObject var iapStore: IAPStore
    @AppStorage("scheduleContentOpacity") private var scheduleContentOpacity: Double = 1.0
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

    private var scheduleCardOpacity: Double
    {
        max(scheduleContentOpacity, 0.9)
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
                if lhs.isOverdue != rhs.isOverdue { return lhs.isOverdue }
                if lhs.priority.sortOrder != rhs.priority.sortOrder { return lhs.priority.sortOrder < rhs.priority.sortOrder }
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
                    .opacity(scheduleCardOpacity)

                if isSubscribed
                {
                    quickAddBar
                        .opacity(scheduleCardOpacity)
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
                        .background(Color(.secondarySystemGroupedBackground).opacity(0.88), in: RoundedRectangle(cornerRadius: 20))
                        .optionalLiquidGlass(enabled: enableLiquidGlassEffect, cornerRadius: 20)
                        .opacity(scheduleCardOpacity)
                        .padding(.horizontal, 12)

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
                    .opacity(scheduleCardOpacity)
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
                    .foregroundColor(.purple)
                    .frame(width: 36, height: 36)
                    .background(Color.purple.opacity(0.1), in: Circle())
                    .optionalLiquidGlass(enabled: enableLiquidGlassEffect, cornerRadius: 18)
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
                    .background(Color.purple.opacity(0.1), in: Capsule())
                    .foregroundColor(.purple)
                    .optionalLiquidGlass(enabled: enableLiquidGlassEffect, cornerRadius: 18)
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
                    .foregroundColor(.purple)
                    .frame(width: 36, height: 36)
                    .background(Color.purple.opacity(0.1), in: Circle())
                    .optionalLiquidGlass(enabled: enableLiquidGlassEffect, cornerRadius: 18)
            }
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
                .onSubmit { addQuickTodo() }

            if !quickAddText.isEmpty
            {
                Button
                {
                    addQuickTodo()
                }
                label:
                {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.purple)
                        .font(.title3)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground).opacity(0.82), in: RoundedRectangle(cornerRadius: 16))
        .optionalLiquidGlass(enabled: enableLiquidGlassEffect, cornerRadius: 16)
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

                Spacer()

                Text("当天日程")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.1), in: Capsule())
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

            if hasCompletedItems
            {
                Button(role: .destructive)
                {
                    clearCompleted()
                }
                label:
                {
                    Text("清理")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.leading, 4)
            }
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
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)

            Button
            {
                navigateToSubscription = true
            }
            label:
            {
                Text("了解校园通行证")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.purple, in: RoundedRectangle(cornerRadius: 12))
                    .optionalLiquidGlass(enabled: enableLiquidGlassEffect, cornerRadius: 12)
            }
            .padding(.horizontal, 16)
        }
    }

    private var addEventButton: some View
    {
        HStack
        {
            Button
            {
                showingAddEvent = true
            }
            label:
            {
                Label("添加日程", systemImage: "plus.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.purple.opacity(0.92), in: Capsule())
                    .optionalLiquidGlass(enabled: enableLiquidGlassEffect, cornerRadius: 28)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.clear)
    }

    private var groupedPersonalEvents: [String: [Event]]
    {
        Dictionary(grouping: filteredPersonalInstances) { $0.formattedDate() }
    }

    private var hasCompletedItems: Bool
    {
        filteredPersonalInstances.contains { $0.isCompleted && $0.category == .todo }
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
            category: .todo,
            priority: .medium
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

    private func clearCompleted()
    {
        let idsToRemove = personalEvents.filter { $0.isCompleted && $0.category == .todo }.map(\.id)
        personalEvents.removeAll { idsToRemove.contains($0.id) }
        EventStore.shared.saveEvents(personalEvents)
    }

    private func bindingForEvent(_ event: Event) -> Binding<Bool>
    {
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
}

// MARK: - 分组标题

private struct SectionHeader: View
{
    let dateKey: String
    let count: Int

    var body: some View
    {
        HStack
        {
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

private struct ScheduleEmptyState: View
{
    @AppStorage("scheduleContentOpacity") private var scheduleContentOpacity: Double = 1.0
    @AppStorage("enableLiquidGlassEffect") private var enableLiquidGlassEffect: Bool = false

    let systemImage: String
    let title: String
    let subtitle: String

    private var cardOpacity: Double
    {
        max(scheduleContentOpacity, 0.92)
    }

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
        .background(Color(.secondarySystemBackground).opacity(0.88), in: RoundedRectangle(cornerRadius: 18))
        .optionalLiquidGlass(enabled: enableLiquidGlassEffect, cornerRadius: 18)
        .opacity(cardOpacity)
        .padding(.horizontal, 16)
    }
}

// MARK: - 个人行程行

private struct PersonalEventRow: View
{
    @AppStorage("scheduleContentOpacity") private var scheduleContentOpacity: Double = 1.0
    @AppStorage("enableLiquidGlassEffect") private var enableLiquidGlassEffect: Bool = false

    let event: Event
    @Binding var completed: Bool

    private var cardOpacity: Double
    {
        max(scheduleContentOpacity, 0.92)
    }

    var body: some View
    {
        HStack(spacing: 10)
        {
            RoundedRectangle(cornerRadius: 2)
                .fill(event.isOverdue ? Color.red : event.displayColor)
                .frame(width: 4, height: 42)

            Button
            {
                completed.toggle()
            }
            label:
            {
                Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(completed ? .green : (event.isOverdue ? .red : .gray))
                    .font(.title3)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3)
            {
                HStack(spacing: 4)
                {
                    if event.priority == .high
                    {
                        Image(systemName: "exclamationmark.3")
                            .font(.system(size: 9))
                            .foregroundColor(.red)
                    }
                    Text(event.title)
                        .font(.system(size: 14, weight: .medium))
                        .strikethrough(completed, color: .gray)
                        .foregroundColor(completed ? .gray : (event.isOverdue ? .red : .primary))
                }

                HStack(spacing: 5)
                {
                    if let timeText = event.formattedTime()
                    {
                        Text(timeText)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    if event.isAllDay
                    {
                        Text("全天")
                            .font(.system(size: 10))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(3)
                    }
                    HStack(spacing: 2)
                    {
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

                    if event.isOverdue
                    {
                        Text("已过期")
                            .font(.system(size: 10))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(3)
                    }

                    let progress = event.subtaskProgress
                    if progress.total > 0
                    {
                        Text("\(progress.done)/\(progress.total)")
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(3)
                    }
                }

                if let due = event.dueDate
                {
                    HStack(spacing: 2)
                    {
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
        .background(Color(.secondarySystemBackground).opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
        .optionalLiquidGlass(enabled: enableLiquidGlassEffect, cornerRadius: 16)
        .opacity(cardOpacity)
    }

    private func relativeDueText(for date: Date) -> String
    {
        let today = Calendar.current.startOfDay(for: Date())
        let dueDay = Calendar.current.startOfDay(for: date)
        let days = Calendar.current.dateComponents([.day], from: today, to: dueDay).day ?? 0
        switch days
        {
        case ..<0: return "已过期\(-days)天"
        case 0: return "今天截止"
        case 1: return "明天截止"
        case 2: return "后天截止"
        case 3 ... 7: return "\(days)天后截止"
        default:
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "zh_CN")
            fmt.dateFormat = "M月d日截止"
            return fmt.string(from: date)
        }
    }

    private func dueDateColor(for date: Date) -> Color
    {
        let today = Calendar.current.startOfDay(for: Date())
        let dueDay = Calendar.current.startOfDay(for: date)
        let days = Calendar.current.dateComponents([.day], from: today, to: dueDay).day ?? 0
        switch days
        {
        case ..<0: return .red
        case 0: return .red
        case 1 ... 2: return .orange
        default: return .secondary
        }
    }
}

#if DEBUG
#Preview("日程")
{
    NavigationStack
    {
        PersonalScheduleView()
            .environmentObject(IAPStore.preview(hasActiveSubscription: false))
    }
}
#endif
