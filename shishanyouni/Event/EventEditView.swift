//
//  EventEditView.swift
//  shishanyouni
//  Created by 寒海澜沧 on 2026/3/20

import SwiftUI

enum EventEditMode {
    case add
    case edit(Event)
    
    var title: String {
        switch self {
        case .add: return "添加日程"
        case .edit: return "编辑日程"
        }
    }
    
    var buttonTitle: String {
        switch self {
        case .add: return "添加"
        case .edit: return "保存"
        }
    }
}

struct EventEditView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var events: [Event]
    
    let mode: EventEditMode
    
    // 表单数据
    @State private var title: String = ""
    @State private var date: Date = Date()
    @State private var isAllDay: Bool = false
    @State private var startTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var endTime: Date = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var note: String = ""
    
    // 行程属性
    @State private var location: String = ""
    @State private var category: EventCategory = .todo
    @State private var colorIndex: Int = 0

    // 优先级 & 截止时间
    @State private var priority: EventPriority = .medium
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()

    // 重复设置
    @State private var isRepeating: Bool = false
    @State private var repeatFrequency: RepeatFrequency = .daily
    @State private var repeatInterval: Int = 1

    // 子任务
    @State private var subtasks: [SubTask] = []
    @State private var newSubtaskTitle: String = ""
    
    private let timeFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "HH:mm"
        return fmt
    }()
    
    init(events: Binding<[Event]>, mode: EventEditMode) {
        _events = events
        self.mode = mode
        
        if case let .edit(event) = mode {
            _title = State(initialValue: event.title)
            _date = State(initialValue: event.date)
            _isAllDay = State(initialValue: event.isAllDay)
            _startTime = State(initialValue: event.startTime ?? Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date())
            _endTime = State(initialValue: event.endTime ?? Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date())
            _note = State(initialValue: event.note ?? "")
            _location = State(initialValue: event.location ?? "")
            _category = State(initialValue: event.category)
            _colorIndex = State(initialValue: event.colorIndex ?? 0)
            _priority = State(initialValue: event.priority)
            _hasDueDate = State(initialValue: event.dueDate != nil)
            _dueDate = State(initialValue: event.dueDate ?? Date())

            if let rule = event.repeatRule {
                _isRepeating = State(initialValue: true)
                _repeatFrequency = State(initialValue: rule.frequency)
                _repeatInterval = State(initialValue: rule.interval)
            }
            _subtasks = State(initialValue: event.subtasks)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("标题", text: $title)
                    
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                    
                    Toggle("全天", isOn: $isAllDay)
                }
                
                if !isAllDay {
                    Section("时间") {
                        DatePicker("开始时间", selection: $startTime, displayedComponents: .hourAndMinute)
                            .environment(\.locale, Locale(identifier: "zh_CN"))
                        
                        DatePicker("结束时间", selection: $endTime, displayedComponents: .hourAndMinute)
                            .environment(\.locale, Locale(identifier: "zh_CN"))
                    }
                }
                
                Section("备注") {
                    TextEditor(text: $note)
                        .frame(minHeight: 80)
                }
                
                Section("行程属性") {
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(.secondary)
                        TextField("地点（选填）", text: $location)
                    }
                    
                    Picker(selection: $category) {
                        ForEach(EventCategory.allCases, id: \.self) { cat in
                            HStack {
                                Image(systemName: cat.systemImage)
                                Text(cat.rawValue)
                            }
                            .tag(cat)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "tag")
                            Text("分类")
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "paintpalette")
                            Text("颜色")
                            Spacer()
                            Circle()
                                .fill(EventColorPalette.color(for: colorIndex))
                                .frame(width: 24, height: 24)
                        }
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                            ForEach(0..<EventColorPalette.colors.count, id: \.self) { idx in
                                Button {
                                    colorIndex = idx
                                } label: {
                                    Circle()
                                        .fill(EventColorPalette.color(for: idx))
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primary, lineWidth: colorIndex == idx ? 3 : 0)
                                        )
                                        .overlay(
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                                .opacity(colorIndex == idx ? 1 : 0)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                
                Section("优先级与截止") {
                    Picker(selection: $priority) {
                        ForEach(EventPriority.allCases, id: \.self) { p in
                            HStack(spacing: 4) {
                                Image(systemName: p.systemImage)
                                    .foregroundColor(p.tintColor)
                                    .font(.system(size: 12))
                                Text(p.rawValue)
                            }
                            .tag(p)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "flag")
                            Text("优先级")
                        }
                    }

                    Toggle(isOn: $hasDueDate) {
                        HStack {
                            Image(systemName: "calendar.badge.exclamationmark")
                            Text("截止时间")
                        }
                    }

                    if hasDueDate {
                        DatePicker("截止", selection: $dueDate, displayedComponents: .date)
                            .environment(\.locale, Locale(identifier: "zh_CN"))
                    }
                }

                Section("重复设置") {
                    Toggle("重复", isOn: $isRepeating)
                    
                    if isRepeating {
                        Picker("频率", selection: $repeatFrequency) {
                            ForEach(RepeatFrequency.allCases, id: \.self) { freq in
                                Text(freq.rawValue).tag(freq)
                            }
                        }
                        
                        HStack {
                            Text("间隔")
                            Spacer()
                            Stepper("每 \(repeatInterval) \(intervalUnit)", value: $repeatInterval, in: 1...30)
                        }
                        
                        Text("此日程将从选定日期开始重复，直到您手动删除")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("子任务") {
                    ForEach($subtasks) { $subtask in
                        HStack {
                            Button {
                                subtask.isCompleted.toggle()
                            } label: {
                                Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(subtask.isCompleted ? .green : .gray)
                            }
                            .buttonStyle(.plain)

                            TextField("子任务", text: $subtask.title)
                        }
                    }
                    .onDelete { subtasks.remove(atOffsets: $0) }

                    HStack {
                        TextField("添加子任务", text: $newSubtaskTitle)
                            .onSubmit {
                                let trimmed = newSubtaskTitle.trimmingCharacters(in: .whitespaces)
                                if !trimmed.isEmpty {
                                    subtasks.append(SubTask(title: trimmed))
                                    newSubtaskTitle = ""
                                }
                            }
                        Button {
                            let trimmed = newSubtaskTitle.trimmingCharacters(in: .whitespaces)
                            if !trimmed.isEmpty {
                                subtasks.append(SubTask(title: trimmed))
                                newSubtaskTitle = ""
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                        .disabled(newSubtaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section("预览") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(EventColorPalette.color(for: colorIndex))
                                .frame(width: 4, height: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(title.isEmpty ? "未命名日程" : title)
                                    .font(.headline)
                                
                                Text(formatDate(date))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        HStack(spacing: 8) {
                            if isAllDay {
                                Text("全天")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                            } else {
                                Text("\(timeFormatter.string(from: startTime)) - \(timeFormatter.string(from: endTime))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: category.systemImage)
                                    .font(.caption)
                                Text(category.rawValue)
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(category.defaultColor.opacity(0.1))
                            .cornerRadius(4)
                        }
                        
                        if !location.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.caption)
                                Text(location)
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: priority.systemImage)
                                .font(.caption)
                            Text(priority.rawValue)
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(priority.tintColor.opacity(0.1))
                        .foregroundColor(priority.tintColor)
                        .cornerRadius(4)

                        if hasDueDate {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .font(.caption)
                                Text("截止: \(formatDate(dueDate))")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }

                        if !note.isEmpty {
                            Text(note)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(mode.buttonTitle) {
                        saveEvent()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
    }
    
    private var intervalUnit: String {
        switch repeatFrequency {
        case .daily: return "天"
        case .weekly: return "周"
        case .biweekly: return "周"
        case .monthly: return "月"
        case .custom: return "天"
        }
    }
    
    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private func saveEvent() {
        let repeatRule: RepeatRule? = isRepeating ? RepeatRule(frequency: repeatFrequency, interval: repeatInterval, endCondition: .never) : nil

        let trimmedLocation = location.trimmingCharacters(in: .whitespaces)
        let finalDueDate: Date? = hasDueDate ? dueDate : nil

        let newEvent: Event
        switch mode {
        case .add:
            newEvent = Event(
                title: title.trimmingCharacters(in: .whitespaces),
                date: date,
                isAllDay: isAllDay,
                startTime: isAllDay ? nil : startTime,
                endTime: isAllDay ? nil : endTime,
                note: note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : note.trimmingCharacters(in: .whitespaces),
                location: trimmedLocation.isEmpty ? nil : trimmedLocation,
                category: category,
                colorIndex: colorIndex,
                isCompleted: false,
                repeatRule: repeatRule,
                priority: priority,
                dueDate: finalDueDate,
                subtasks: subtasks
            )
            events.append(newEvent)

        case let .edit(oldEvent):
            newEvent = Event(
                id: oldEvent.id,
                title: title.trimmingCharacters(in: .whitespaces),
                date: date,
                isAllDay: isAllDay,
                startTime: isAllDay ? nil : startTime,
                endTime: isAllDay ? nil : endTime,
                note: note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : note.trimmingCharacters(in: .whitespaces),
                location: trimmedLocation.isEmpty ? nil : trimmedLocation,
                category: category,
                colorIndex: colorIndex,
                isCompleted: oldEvent.isCompleted,
                repeatRule: repeatRule,
                priority: priority,
                dueDate: finalDueDate,
                subtasks: subtasks
            )
            if let index = events.firstIndex(where: { $0.id == oldEvent.id }) {
                events[index] = newEvent
            }
        }
        
        EventStore.shared.saveEvents(events)
        dismiss()
    }
    
    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "yyyy年MM月dd日 (EEEE)"
        return fmt.string(from: date)
    }
}

#Preview {
    EventEditView(events: .constant([]), mode: .add)
}
