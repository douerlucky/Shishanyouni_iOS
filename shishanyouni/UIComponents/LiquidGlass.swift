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
    let tint: Color?
    let fallback: Color
    let interactive: Bool
    @Environment(\.isInsideLiquidGlassSurface) private var isInsideSurface
    @AppStorage(PreferenceKey.enableLiquidGlassEffect) private var glassEnabled = true

    func body(content: Content) -> some View
    {
        if #available(iOS 26.0, *), enabled && glassEnabled && (!isInsideSurface || allowsNesting)
        {
            content
                .environment(\.isInsideLiquidGlassSurface, true)
                .background
                {
                    // 玻璃与前景分层；只淡化底板，文字和图标不受组件滑块影响。
                    Color.clear
                        .glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
                        .componentBackgroundOpacity()
                        .allowsHitTesting(interactive)
                }
        }
        else
        {
            // 未绘制玻璃就不新增边界，纯色父容器里的独立玻璃仍然可用。
            content
                .background
                {
                    shape.fill(fallback)
                        .componentBackgroundOpacity()
                        .allowsHitTesting(false)
                }
        }
    }
}

extension View
{
    /// fallback 仅在玻璃关闭、不受支持或被父层玻璃抑制时绘制，不会叠在玻璃下面。
    func optionalLiquidGlass<S: Shape>(
        enabled: Bool = true,
        allowsNesting: Bool = false,
        in shape: S,
        tint: Color? = nil,
        fallback: Color = .clear,
        interactive: Bool = false
    ) -> some View
    {
        modifier(OptionalLiquidGlass(
            enabled: enabled,
            allowsNesting: allowsNesting,
            shape: shape,
            tint: tint,
            fallback: fallback,
            interactive: interactive
        ))
    }

    func optionalLiquidGlass(
        enabled: Bool = true,
        allowsNesting: Bool = false,
        cornerRadius: CGFloat = 64,
        tint: Color? = nil,
        fallback: Color = .clear,
        interactive: Bool = false
    ) -> some View
    {
        optionalLiquidGlass(
            enabled: enabled,
            allowsNesting: allowsNesting,
            in: RoundedRectangle(cornerRadius: cornerRadius),
            tint: tint,
            fallback: fallback,
            interactive: interactive
        )
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
    func body(content: Content) -> some View
    {
        content
            .optionalLiquidGlass(
                in: shape,
                fallback: Color(uiColor: .secondarySystemBackground)
            )
    }
}
