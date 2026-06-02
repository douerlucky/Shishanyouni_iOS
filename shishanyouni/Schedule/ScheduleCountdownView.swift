//
//  ScheduleCountdownView.swift
//  shishanyouni
//
//  倒计时面板：距考试周 / 距假期 / 距学期结束
//

import SwiftUI

struct CountdownItem: Identifiable {
    let id = UUID()
    let title: String
    let targetDate: Date
    let icon: String
    let color: Color

    var daysRemaining: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let target = cal.startOfDay(for: targetDate)
        return cal.dateComponents([.day], from: today, to: target).day ?? 0
    }

    var isExpired: Bool { daysRemaining < 0 }
}

struct ScheduleCountdownView: View {
    let items: [CountdownItem]

    var body: some View {
        if items.isEmpty { EmptyView() }
        else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(items) { item in
                        countdownCard(item)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    @ViewBuilder
    private func countdownCard(_ item: CountdownItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: item.icon)
                .font(.system(size: 16))
                .foregroundColor(item.color)
                .frame(width: 32, height: 32)
                .background(item.color.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if item.isExpired {
                    Text("已过")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                } else if item.daysRemaining == 0 {
                    Text("今天")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(item.color)
                } else {
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text("\(item.daysRemaining)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(item.daysRemaining <= 7 ? .red : item.color)
                        Text("天")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    static func buildCountdownItems() -> [CountdownItem] {
        let events = SchoolCalendarStore.shared.loadEvents()
        let today = Calendar.current.startOfDay(for: Date())
        var items: [CountdownItem] = []

        let examEvents = events
            .filter { $0.type == .exam && Calendar.current.startOfDay(for: $0.startDate) > today }
            .sorted { $0.startDate < $1.startDate }
        if let nextExam = examEvents.first {
            items.append(CountdownItem(
                title: "距考试周",
                targetDate: nextExam.startDate,
                icon: "pencil.and.list.clipboard",
                color: .orange
            ))
        }

        let holidayEvents = events
            .filter { $0.type == .holiday && Calendar.current.startOfDay(for: $0.startDate) > today }
            .sorted { $0.startDate < $1.startDate }
        if let nextHoliday = holidayEvents.first {
            items.append(CountdownItem(
                title: "距\(nextHoliday.title)",
                targetDate: nextHoliday.startDate,
                icon: "sun.max.fill",
                color: .green
            ))
        }

        let endEvents = events
            .filter { $0.type == .trimesterEnd && Calendar.current.startOfDay(for: $0.startDate) > today }
            .sorted { $0.startDate < $1.startDate }
        if let nextEnd = endEvents.first {
            items.append(CountdownItem(
                title: "距\(nextEnd.title)",
                targetDate: nextEnd.startDate,
                icon: "flag.checkered",
                color: .purple
            ))
        }

        let semesterStart = SchoolCalendarStore.shared.semesterStartDate()
        let cal = Calendar.current
        let startComps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: semesterStart)
        if let firstMonday = cal.date(from: startComps),
           let semesterEnd = cal.date(byAdding: .weekOfYear, value: 19, to: firstMonday),
           cal.startOfDay(for: semesterEnd) > today {
            items.append(CountdownItem(
                title: "距学期结束",
                targetDate: semesterEnd,
                icon: "calendar.badge.clock",
                color: .blue
            ))
        }

        return items
    }
}

#Preview {
    ScheduleCountdownView(items: ScheduleCountdownView.buildCountdownItems())
}
