import SwiftUI

/// 账号绑定、查询等页面共用的服务来源选项。
protocol QuerySourceOption: CaseIterable, Hashable, Identifiable
{
    var title: String { get }
}

/// 已在页面内展示的双来源使用系统分段选择器，避免再叠加一层选择 Sheet。
struct DataSourceTabs<Source: QuerySourceOption>: View
{
    @Binding var selection: Source

    var body: some View
    {
        Picker("数据源", selection: $selection)
        {
            ForEach(Array(Source.allCases)) { source in Text(source.title).tag(source) }
        }
        .pickerStyle(.segmented)
    }
}

struct DataSourceSelector<Source: QuerySourceOption>: View
{
    @Binding var selection: Source
    var fontSize: CGFloat = 14
    var foreground: Color = .primary
    var selectionTitle: String = "选择数据源"
    var onSelect: ((Source) -> Void)? = nil

    var body: some View
    {
        Menu
        {
            Picker(selectionTitle, selection: Binding(
                get: { selection },
                set: { source in
                    if let onSelect { onSelect(source) }
                    else { selection = source }
                }
            ))
            {
                ForEach(Array(Source.allCases)) { source in Text(source.title).tag(source) }
            }
        }
        label:
        {
            HStack(spacing: 6)
            {
                Text(selection.title)
                    .font(.system(size: fontSize, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .allowsTightening(true)
                    .appTextOpacity()
                    .frame(maxWidth: .infinity)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Capsule())
        }
        // Menu 直接接收 Apple 的样式，不经过 Button(configuration) 的按钮转发封装。
        .menuStyle(.button)
        .modifier(DataSourceMenuButtonStyle())
        .controlSize(.mini)
        .frame(height: QueryControlMetrics.height)
        .accessibilityLabel(selectionTitle)
        .accessibilityValue(selection.title)
    }
}

/// Menu 的原生触发器单独配置；不是额外绘制一个背景。
private struct DataSourceMenuButtonStyle: ViewModifier
{
    @AppStorage(PreferenceKey.enableLiquidGlassEffect) private var glassEnabled = true
    private let tint = Color.primary.opacity(0.18)

    @ViewBuilder
    func body(content: Content) -> some View
    {
        if #available(iOS 26.1, *), glassEnabled
        {
            content
                .buttonStyle(.glass(.regular.tint(tint)))
                .buttonBorderShape(.capsule)
                .buttonSizing(.flexible)
        }
        else if #available(iOS 26.0, *), glassEnabled
        {
            content
                .buttonStyle(.glass)
                .tint(tint)
                .buttonBorderShape(.capsule)
                .buttonSizing(.flexible)
        }
        else
        {
            content
                .buttonStyle(.bordered)
                .tint(tint)
                .buttonBorderShape(.capsule)
        }
    }
}

/// 年份/学期按钮的统一外观；年份和学期的 wheel 内容由业务页面提供。
struct SemesterSelector: View
{
    let title: String
    let action: () -> Void
    var width: CGFloat = 112

    var body: some View
    {
        Button(action: action)
        {
            HStack(spacing: 4)
            {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .allowsTightening(true)
                    .appTextOpacity()
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .bold))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(.primary)
            .contentShape(Capsule())
        }
        .nativeGlassButtonStyle(fillsWidth: true)
        .controlSize(.mini)
        .frame(width: width, height: QueryControlMetrics.height)
    }
}

/// 教学楼位置选择器的通用触发按钮。
struct TeachingBuildingSelector: View
{
    let title: String
    let action: () -> Void

    var body: some View
    {
        Button(action: action)
        {
            HStack(spacing: 4)
            {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .appTextOpacity()
                Image(systemName: "chevron.up")
                    .font(.system(size: 8, weight: .bold))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(.primary)
            .contentShape(Capsule())
        }
        .nativeGlassButtonStyle(fillsWidth: true)
        .controlSize(.mini)
        .frame(height: QueryControlMetrics.height)
    }
}

