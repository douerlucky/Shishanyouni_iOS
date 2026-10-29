import SwiftUI

struct DayCell: View {
    let dayInfo: DayInfo
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 1) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Color.blue)
                        .componentBackgroundOpacity()
                        .frame(width: 30, height: 30)
                } else if dayInfo.isToday {
                    Circle()
                        .stroke(Color.blue, lineWidth: 1.5)
                        .frame(width: 30, height: 30)
                }

                Text("\(dayInfo.day)")
                    .font(.system(size: 14, weight: dayInfo.isToday ? .semibold : .regular))
                    .foregroundColor(dayInfo.isCurrentMonth ? (isSelected ? .white : (dayInfo.isToday ? .blue : .primary)) : .secondary.opacity(0.4))
                    .appTextOpacity()
            }

            HStack(spacing: 3) {
                if dayInfo.hasSchoolEvent {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 5, height: 5)
                }
                if dayInfo.hasPersonalEvent {
                    Circle()
                        .fill(Color.purple)
                        .frame(width: 5, height: 5)
                }
            }
            .frame(height: 8)
        }
        .frame(height: 44)
        .contentShape(Rectangle())
    }
}
