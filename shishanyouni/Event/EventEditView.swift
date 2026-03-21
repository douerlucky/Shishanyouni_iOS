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
    
    // 重复设置
    @State private var isRepeating: Bool = false
    @State private var repeatFrequency: RepeatFrequency = .daily
    @State private var repeatInterval: Int = 1
    
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
            
            if let rule = event.repeatRule {
                _isRepeating = State(initialValue: true)
                _repeatFrequency = State(initialValue: rule.frequency)
                _repeatInterval = State(initialValue: rule.interval)
            }
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
                
                Section("预览") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title.isEmpty ? "未命名日程" : title)
                            .font(.headline)
                        
                        Text(formatDate(date))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
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
                isCompleted: false,
                repeatRule: repeatRule
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
                isCompleted: oldEvent.isCompleted,
                repeatRule: repeatRule
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
