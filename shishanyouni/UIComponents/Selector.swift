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
    var horizontalPadding: CGFloat = 16
    var verticalPadding: CGFloat = 10
    var foreground: Color = .primary
    var selectionTitle: String = "选择数据源"
    var onSelect: ((Source) -> Void)? = nil

    @State private var isPresented = false

    var body: some View
    {
        Button { isPresented = true }
        label:
        {
            HStack(spacing: 6)
            {
                Text(selection.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .font(.system(size: fontSize, weight: .bold))
            .foregroundStyle(foreground)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(.ultraThinMaterial, in: Capsule())
            .clipShape(Capsule())
            .optionalLiquidGlass(allowsNesting: true, in: Capsule())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isPresented)
        {
            VStack(spacing: 18)
            {
                Text(selectionTitle)
                    .font(.headline)

                VStack(spacing: 12)
                {
                    ForEach(Array(Source.allCases))
                    { source in
                        Button
                        {
                            onSelect?(source)
                            if onSelect == nil { selection = source }
                            isPresented = false
                        }
                        label:
                        {
                            HStack
                            {
                                Text(source.title)
                                    .font(.system(size: 17, weight: .bold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                Spacer()
                                if selection == source
                                {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .foregroundStyle(selection == source ? .blue : .primary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 15)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .optionalLiquidGlass(allowsNesting: true, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                CancelButton("取消") { isPresented = false }
                    .frame(maxWidth: 160)
            }
            .padding(24)
            // 新呈现的 Sheet 是独立界面，不继承查询栏的“玻璃内部”状态。
            .environment(\.isInsideLiquidGlassSurface, false)
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.hidden)
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
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .clipShape(Capsule())
            .optionalLiquidGlass(allowsNesting: true, in: Capsule())
        }
        .buttonStyle(.plain)
        .frame(width: width)
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
                Image(systemName: "chevron.up")
                    .font(.system(size: 8, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(.primary)
            .background(.ultraThinMaterial, in: Capsule())
            .clipShape(Capsule())
            .optionalLiquidGlass(allowsNesting: true, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

