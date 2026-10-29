import SwiftUI
import UIKit

// MARK: - 分组标题

struct SectionHeader: View
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
                .appTextOpacity()

            Text("\(count)项")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .appTextOpacity()
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background { Capsule().fill(Color(.systemGray5)).componentBackgroundOpacity() }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }
}

struct ScheduleEmptyState: View
{
    @AppStorage("enableLiquidGlassEffect") private var enableLiquidGlassEffect: Bool = false

    let systemImage: String
    let title: String
    let subtitle: String

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
                .appTextOpacity()
            Text(subtitle)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary.opacity(0.65))
                .appTextOpacity()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
        .optionalLiquidGlass(
            enabled: enableLiquidGlassEffect,
            cornerRadius: 18,
            fallback: Color(.secondarySystemBackground).opacity(0.88)
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - 个人行程行

struct PersonalEventRow: View
{
    @AppStorage("enableLiquidGlassEffect") private var enableLiquidGlassEffect: Bool = false

    let event: Event
    @Binding var completed: Bool

    var body: some View
    {
        HStack(spacing: 10)
        {
            RoundedRectangle(cornerRadius: 2)
                .fill(event.displayColor)
                .frame(width: 4, height: 42)

            Button
            {
                completed.toggle()
            }
            label:
            {
                Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(completed ? .green : .gray)
                    .font(.title3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .nativeGlassButtonStyle(prominent: completed, shape: .circle, fillsWidth: true, backgroundTint: completed ? .green : nil)
            .tint(.green)
            .controlSize(.mini)
            .frame(width: 32, height: 32)
            .accessibilityLabel(completed ? "标记为未完成" : "标记为已完成")

            VStack(alignment: .leading, spacing: 3)
            {
                Text(event.title)
                    .font(.system(size: 14, weight: .medium))
                    .strikethrough(completed, color: .gray)
                    .foregroundColor(completed ? .gray : .primary)
                    .appTextOpacity()

                HStack(spacing: 5)
                {
                    if let timeText = event.formattedTime()
                    {
                        Text(timeText)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .appTextOpacity()
                    }
                    if event.isAllDay
                    {
                        Text("全天")
                            .font(.system(size: 10))
                            .appTextOpacity()
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background { Color.blue.opacity(0.1).componentBackgroundOpacity() }
                            .foregroundColor(.blue)
                            .cornerRadius(3)
                    }
                    HStack(spacing: 2)
                    {
                        Image(systemName: event.category.systemImage)
                            .font(.system(size: 8))
                        Text(event.category.rawValue)
                            .appTextOpacity()
                    }
                    .font(.system(size: 10))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background { event.category.defaultColor.opacity(0.1).componentBackgroundOpacity() }
                    .foregroundColor(event.category.defaultColor)
                    .cornerRadius(3)
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .optionalLiquidGlass(
            enabled: enableLiquidGlassEffect,
            cornerRadius: 16,
            fallback: Color(.secondarySystemBackground).opacity(0.9)
        )
    }
}

// MARK: - 上下文预览卡片

struct EventContextPreview: View
{

    let event: Event
    let completed: Bool

    var body: some View
    {
        VStack(alignment: .leading, spacing: 10)
        {
            HStack(spacing: 8)
            {
                RoundedRectangle(cornerRadius: 3)
                    .fill(event.displayColor)
                    .frame(width: 5, height: 36)

                VStack(alignment: .leading, spacing: 4)
                {
                    Text(event.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(completed ? .secondary : .primary)
                        .strikethrough(completed)

                    HStack(spacing: 6)
                    {
                        Text(event.category.rawValue)
                            .font(.system(size: 11))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(event.category.defaultColor.opacity(0.12))
                            .foregroundColor(event.category.defaultColor)
                            .cornerRadius(4)
                        if let loc = event.location, !loc.isEmpty
                        {
                            Label(loc, systemImage: "mappin.and.ellipse")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6)
            {
                HStack(spacing: 8)
                {
                    Label(event.formattedDate(), systemImage: "calendar")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    if let time = event.formattedTime()
                    {
                        Label(time, systemImage: "clock")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    if event.isAllDay
                    {
                        Text("全天")
                            .font(.system(size: 11))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }

                if let note = event.note, !note.isEmpty
                {
                    Text(note)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            if completed
            {
                HStack(spacing: 4)
                {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("已完成")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(16)
        .frame(width: 280)
        .background
        {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .componentBackgroundOpacity()
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
