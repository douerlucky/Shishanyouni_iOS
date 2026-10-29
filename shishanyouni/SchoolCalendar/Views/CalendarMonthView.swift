import SwiftUI

struct CalendarMonthView: View {
    let month: Date
    let schoolEvents: [SchoolCalendarEvent]
    let personalEvents: [Event]
    @Binding var selectedDate: Date
    
    private let calendar = Calendar.current
    private let weekdays = ["一", "二", "三", "四", "五", "六", "日"]
    
    private var year: Int { calendar.component(.year, from: month) }
    private var monthNumber: Int { calendar.component(.month, from: month) }
    
    var body: some View {
        VStack(spacing: 0) {
            monthHeader
            weekdayHeader
            dayGrid
        }
    }
    
    private var monthHeader: some View {
        Text("\(String(year))年 \(monthNumber)月")
            .font(.system(size: 18, weight: .semibold))
            .appTextOpacity()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
    }
    
    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekdays, id: \.self) { day in
                Text(day)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(day == "六" || day == "日" ? .secondary : .primary)
                    .appTextOpacity()
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 4)
    }
    
    private var dayGrid: some View {
        let days = generateDays()
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        
        return LazyVGrid(columns: columns, spacing: 2) {
            ForEach(days) { dayInfo in
                DayCell(
                    dayInfo: dayInfo,
                    isSelected: calendar.isDate(dayInfo.date, inSameDayAs: selectedDate)
                )
                .onTapGesture {
                    selectedDate = dayInfo.date
                }
            }
        }
    }
    
    private func generateDays() -> [DayInfo] {
        var days: [DayInfo] = []
        
        guard let firstDay = calendar.date(from: DateComponents(year: year, month: monthNumber, day: 1)) else {
            return days
        }
        
        let weekday = calendar.component(.weekday, from: firstDay)
        let offsetFromMonday = (weekday + 5) % 7
        
        let today = calendar.startOfDay(for: Date())
        
        let range = calendar.range(of: .day, in: .month, for: firstDay) ?? 1..<31
        let daysInMonth = range.count
        
        // Previous month padding
        if offsetFromMonday > 0, let prevMonth = calendar.date(byAdding: .month, value: -1, to: firstDay) {
            let prevRange = calendar.range(of: .day, in: .month, for: prevMonth) ?? 1..<31
            let prevDays = prevRange.count
            for i in 0..<offsetFromMonday {
                let day = prevDays - offsetFromMonday + i + 1
                var comps = calendar.dateComponents([.year, .month], from: prevMonth)
                comps.day = day
                if let date = calendar.date(from: comps) {
                    days.append(DayInfo(date: date, day: day, isCurrentMonth: false, isToday: calendar.isDate(date, inSameDayAs: today)))
                }
            }
        }
        
        // Current month days
        for day in 1...daysInMonth {
            var comps = calendar.dateComponents([.year, .month], from: firstDay)
            comps.day = day
            if let date = calendar.date(from: comps) {
                let schoolCount = schoolEvents.filter { $0.contains(date: date) }.count
                let dayStart = calendar.startOfDay(for: date)
                let dayEnd = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: dayStart) ?? dayStart
                let personalCount = personalEvents.flatMap { $0.instances(in: dayStart...dayEnd) }.count
                days.append(DayInfo(
                    date: date,
                    day: day,
                    isCurrentMonth: true,
                    isToday: calendar.isDate(date, inSameDayAs: today),
                    schoolEventCount: schoolCount,
                    personalEventCount: personalCount
                ))
            }
        }
        
        // Next month padding to fill last row
        let remaining = (7 - days.count % 7) % 7
        if remaining > 0, let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstDay) {
            for day in 1...remaining {
                var comps = calendar.dateComponents([.year, .month], from: nextMonth)
                comps.day = day
                if let date = calendar.date(from: comps) {
                    days.append(DayInfo(date: date, day: day, isCurrentMonth: false, isToday: calendar.isDate(date, inSameDayAs: today)))
                }
            }
        }
        
        return days
    }
}

#Preview {
    CalendarMonthView(
        month: Date(),
        schoolEvents: [],
        personalEvents: [],
        selectedDate: .constant(Date())
    )
    .padding()
}
