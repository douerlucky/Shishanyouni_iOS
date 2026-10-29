import SwiftUI
import Foundation

// MARK: - 时间格式化

private func formatEventTime(_ date: Date) -> String
{
    let cal = Calendar.current

    if cal.isDateInToday(date) { return "今天" + formatTimeOnly(date) }
    if isTomorrow(date) { return "明天" + formatTimeOnly(date) }
    if isDayAfterTomorrow(date) { return "后天" + formatTimeOnly(date) }

    let fmt = DateFormatter()
    fmt.locale = Locale(identifier: "zh_CN")
    fmt.dateFormat = "M月d日 HH:mm"
    return fmt.string(from: date)
}

private func formatTimeOnly(_ date: Date) -> String
{
    let fmt = DateFormatter()
    fmt.dateFormat = " HH:mm"
    return fmt.string(from: date)
}

private func isTomorrow(_ date: Date) -> Bool
{
    Calendar.current.isDate(Date().addingTimeInterval(86400), inSameDayAs: date)
}

private func isDayAfterTomorrow(_ date: Date) -> Bool
{
    Calendar.current.isDate(Date().addingTimeInterval(172800), inSameDayAs: date)
}

// MARK: - View

struct NextEventView: View
{
    @AppStorage(PreferenceKey.enableLiquidGlassEffect) private var enableLiquidGlassEffect: Bool = true
    @StateObject private var vm = NextEventViewModel()

    var body: some View
    {
        GeometryReader { proxy in
            let containerWidth = proxy.size.width
            let cardWidth: CGFloat = 290               // 卡片固定宽度，比屏幕窄
            let firstCardLeading = (containerWidth - cardWidth) / 2  // 第一张卡片居中

            Group
            {
                if vm.nextEvents.isEmpty
                {
                    emptyCard(width: cardWidth)
                        .padding(.leading, firstCardLeading)
                }
                else
                {
                    ScrollView(.horizontal, showsIndicators: false)
                    {
                        LazyHStack(spacing: 12)
                        {
                            ForEach(vm.nextEvents) { event in
                                eventCard(event)
                                    .frame(width: cardWidth)
                            }
                        }
                        .padding(.leading, firstCardLeading)
                        .padding(.trailing, 16)  // 右侧露出下一张卡片边缘
                    }
                }
            }
        }
        .frame(height: 132)
        // 首次显示和任一数据源写入后都会刷新，保持首页卡片与课表/日程同步。
        .onAppear { vm.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .homeNextEventsDidChange)) { _ in
            vm.refresh()
        }
    }

    private func emptyCard(width: CGFloat) -> some View
    {
        LiquidGlassCard(enabled: enableLiquidGlassEffect)
        {
            HStack(spacing: 14)
            {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 4)
                {
                    Text("接下来 3 天暂无安排")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .appTextOpacity()
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(width: width, height: 120, alignment: .leading)
        }
    }

    @ViewBuilder
    private func eventCard(_ event: NextEventItem) -> some View
    {
        LiquidGlassCard(enabled: enableLiquidGlassEffect)
        {
            HStack(spacing: 14)
            {
            // 左侧：图标 + 类型标签
            VStack(spacing: 6)
            {
                ZStack
                {
                    let iconShape = RoundedRectangle(cornerRadius: 14, style: .continuous)
                    iconShape
                        .fill(event.type.color.opacity(0.12))
                        .componentBackgroundOpacity()
                        .frame(width: 48, height: 48)
                        .clipShape(iconShape)

                    Image(systemName: event.type.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(event.type.color)
                }

                Text(event.type.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(event.type.color)
                    .appTextOpacity()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background
                    {
                        Capsule().fill(event.type.color.opacity(0.10))
                            .componentBackgroundOpacity()
                    }
                    .clipShape(Capsule())
            }

            // 中间文字
            VStack(alignment: .leading, spacing: 3)
            {
                Text(event.title)
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)
                    .appTextOpacity()

                if let sub = event.subtitle, !sub.isEmpty
                {
                    Label(sub, systemImage: "location.fill")
                        .labelStyle(TextOpacityLabelStyle())
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if let detail = event.detail, !detail.isEmpty
                {
                    Label(detail, systemImage: "person.fill")
                        .labelStyle(TextOpacityLabelStyle())
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Text(formatEventTime(event.date))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(event.type.color.opacity(0.8))
                    .appTextOpacity()
            }

            Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 132)
        }
    }
}

#Preview
{
    NextEventView()
}
