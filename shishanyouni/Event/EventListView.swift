//
//  EventListView.swift
//  shishanyouni
// Created by 寒海澜沧 on 2026/3/20

import SwiftUI
import Foundation

struct EventListView: View {
    @State private var originalEvents: [Event] = []
    @State private var completions: [String: Bool] = [:]
    @State private var showingAddEvent = false
    @State private var editingEvent: Event?
    @State private var refreshToggle = false
    
    private var dateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 30, to: start)!
        return start...end
    }
    
    private var displayInstances: [Event] {
        originalEvents
            .flatMap { $0.instances(in: dateRange) }
            .sorted { a, b in
                if a.isOverdue != b.isOverdue { return a.isOverdue }
                if a.priority.sortOrder != b.priority.sortOrder { return a.priority.sortOrder < b.priority.sortOrder }
                return a.date < b.date
            }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedEvents.keys.sorted(), id: \.self) { dateKey in
                    Section(header: Text(dateKey)) {
                        ForEach(groupedEvents[dateKey] ?? []) { event in
                            EventRow(event: event, completed: bindingForEvent(event))
                                .id("\(event.id)_\(refreshToggle)")
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
            .navigationTitle("私人行程与日程")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddEvent = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddEvent) {
                EventEditView(events: $originalEvents, mode: .add)
            }
            .sheet(item: $editingEvent) { event in
                EventEditView(events: $originalEvents, mode: .edit(event))
            }
            .onAppear {
                loadEvents()
            }
        }
    }
    
    private var groupedEvents: [String: [Event]] {
        Dictionary(grouping: displayInstances) { event in
            event.formattedDate()
        }
    }
    
    private func loadEvents() {
        var loadedEvents = EventStore.shared.loadEvents()
        
        // 删除包含"背单词"的日程
        loadedEvents.removeAll { event in
            event.title.contains("背单词")
        }
        
        // 如果有删除，保存更新后的列表
        if loadedEvents.count != EventStore.shared.loadEvents().count {
            EventStore.shared.saveEvents(loadedEvents)
        }
        
        originalEvents = loadedEvents
        completions = EventStore.shared.getAllCompletions()
    }
    
    private func saveEvents() {
        EventStore.shared.saveEvents(originalEvents)
    }
    
    private func deleteEvent(_ event: Event) {
        originalEvents.removeAll { $0.id == event.id }
        EventStore.shared.removeCompletions(for: event.id)
        saveEvents()
    }
    
    private func bindingForEvent(_ event: Event) -> Binding<Bool> {
        Binding(
            get: {
                let completed = EventStore.shared.isCompleted(eventId: event.id, date: event.date)
                print("读取完成状态: \(event.title) \(event.date) -> \(completed)")
                return completed
            },
            set: { newValue in
                print("设置完成状态: \(event.title) \(event.date) -> \(newValue)")
                EventStore.shared.setCompletion(eventId: event.id, date: event.date, completed: newValue)
                // 更新本地completions以触发UI更新
                var newCompletions = completions
                let key = EventStore.shared.completionKey(for: event.id, date: event.date)
                newCompletions[key] = newValue
                completions = newCompletions
                print("completions更新: \(key) = \(newValue)")
                // 强制刷新UI
                refreshToggle.toggle()
                print("refreshToggle切换: \(refreshToggle)")
            }
        )
    }
}

struct EventRow: View {
    let event: Event
    @Binding var completed: Bool

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(event.isOverdue ? Color.red : event.displayColor)
                .frame(width: 4, height: 48)

            Button {
                print("EventRow 按钮点击: \(event.title)")
                completed.toggle()
                print("EventRow completed 状态: \(completed)")
            } label: {
                Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(completed ? .green : (event.isOverdue ? .red : .gray))
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    if event.priority == .high {
                        Image(systemName: "exclamationmark.3")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                    }
                    Text(event.title)
                        .font(.headline)
                        .strikethrough(completed, color: .gray)
                        .foregroundColor(completed ? .gray : (event.isOverdue ? .red : .primary))
                }

                HStack(spacing: 6) {
                    if let timeText = event.formattedTime() {
                        Text(timeText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if event.isAllDay {
                        Text("全天")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(3)
                    }

                    HStack(spacing: 2) {
                        Image(systemName: event.category.systemImage)
                            .font(.system(size: 9))
                        Text(event.category.rawValue)
                    }
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(event.category.defaultColor.opacity(0.1))
                    .foregroundColor(event.category.defaultColor)
                    .cornerRadius(3)

                    HStack(spacing: 2) {
                        Image(systemName: event.priority.systemImage)
                            .font(.system(size: 9))
                        Text(event.priority.rawValue)
                    }
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(event.priority.tintColor.opacity(0.1))
                    .foregroundColor(event.priority.tintColor)
                    .cornerRadius(3)

                    if event.isOverdue {
                        Text("已过期")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(3)
                    }
                }

                if let due = event.dueDate {
                    HStack(spacing: 2) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 10))
                        Text("截止: \(formatDueDate(due))")
                            .font(.caption2)
                            .foregroundColor(event.isOverdue ? .red : .secondary)
                    }
                }

                if let location = event.location, !location.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 10))
                        Text(location)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                if let note = event.note, !note.isEmpty {
                    Text(note)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .onChange(of: completed) { newValue in
            print("EventRow completed 变化: \(newValue)")
        }
    }

    private func formatDueDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "M月d日"
        return fmt.string(from: date)
    }
}

#Preview {
    EventListView()
}
