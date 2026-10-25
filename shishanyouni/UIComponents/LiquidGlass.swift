import SwiftUI

enum LiquidGlassAvailability
{
    static var isSupported: Bool
    {
        if #available(iOS 26.0, *) { return true }
        return false
    }
}

private struct InsideLiquidGlassSurfaceKey: EnvironmentKey
{
    static let defaultValue = false
}

/// 保留独立组件原有的材质底；放在玻璃上时换成普通填充，避免继续叠加模糊。
struct LiquidGlassBase<S: Shape>: View
{
    let shape: S
    // 由组件在绘制自身玻璃前读取父层级，避免把自身误判为另一层玻璃。
    let isInsideSurface: Bool

    var body: some View
    {
        if isInsideSurface
        {
            shape.fill(Color(uiColor: .secondarySystemBackground))
        }
        else
        {
            shape.fill(.ultraThinMaterial)
        }
    }
}

extension EnvironmentValues
{
    /// 仅记录 App 自己绘制的玻璃容器，系统 Sheet、导航栈不算一层玻璃。
    var isInsideLiquidGlassSurface: Bool
    {
        get { self[InsideLiquidGlassSurfaceKey.self] }
        set { self[InsideLiquidGlassSurfaceKey.self] = newValue }
    }
}

/// 普通内容避免叠玻璃；按钮、课表状态标识等明确的例外可允许嵌套。
private struct OptionalLiquidGlass<S: Shape>: ViewModifier
{
    let enabled: Bool
    let allowsNesting: Bool
    let shape: S
    @Environment(\.isInsideLiquidGlassSurface) private var isInsideSurface
    @AppStorage(PreferenceKey.enableLiquidGlassEffect) private var glassEnabled = true

    func body(content: Content) -> some View
    {
        if #available(iOS 26.0, *), enabled && glassEnabled && (!isInsideSurface || allowsNesting)
        {
            content
                .environment(\.isInsideLiquidGlassSurface, true)
                .glassEffect(.clear, in: shape)
        }
        else
        {
            // 未绘制玻璃就不新增边界，纯色父容器里的独立玻璃仍然可用。
            content
        }
    }
}

extension View
{
    func optionalLiquidGlass<S: Shape>(enabled: Bool = true, allowsNesting: Bool = false, in shape: S) -> some View
    {
        modifier(OptionalLiquidGlass(enabled: enabled, allowsNesting: allowsNesting, shape: shape))
    }

    func optionalLiquidGlass(enabled: Bool = true, allowsNesting: Bool = false, cornerRadius: CGFloat = 64) -> some View
    {
        optionalLiquidGlass(enabled: enabled, allowsNesting: allowsNesting, in: RoundedRectangle(cornerRadius: cornerRadius))
    }

    func glassBackground(cornerRadius: CGFloat = 64) -> some View
    {
        glassBackground(in: RoundedRectangle(cornerRadius: cornerRadius))
    }

    func glassBackground<S: InsettableShape>(in shape: S) -> some View
    {
        modifier(GlassBackground(shape: shape))
    }
}

/// 浮动工具条的背景；普通内容退回纯色，按钮可显式保留自己的玻璃。
private struct GlassBackground<S: InsettableShape>: ViewModifier
{
    let shape: S
    @Environment(\.isInsideLiquidGlassSurface) private var isInsideSurface
    @AppStorage(PreferenceKey.enableLiquidGlassEffect) private var glassEnabled = true
    @AppStorage(PreferenceKey.pageBackgroundOpacity) private var backgroundOpacity = 0.35

    func body(content: Content) -> some View
    {
        content
            .environment(
                \.isInsideLiquidGlassSurface,
                isInsideSurface || (glassEnabled && LiquidGlassAvailability.isSupported)
            )
            .background
            {
                Group
                {
                    if #available(iOS 26.0, *), glassEnabled && !isInsideSurface
                    {
                        Color.clear.glassEffect(.regular, in: shape)
                    }
                    else
                    {
                        shape.fill(Color(uiColor: .secondarySystemBackground))
                    }
                }
                .opacity(backgroundOpacity)
            }
    }
}
