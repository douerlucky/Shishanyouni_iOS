import SwiftUI

/// 两个偏好分别应用在文字和底板，不给混合内容的整个容器统一加透明度。
private struct TextOpacityModifier: ViewModifier
{
    @AppStorage(PreferenceKey.textOpacity) private var opacity = 1.0

    func body(content: Content) -> some View
    {
        content.opacity(opacity)
    }
}

private struct ComponentOpacityModifier: ViewModifier
{
    @AppStorage(PreferenceKey.componentOpacity) private var opacity = 1.0

    func body(content: Content) -> some View
    {
        content.opacity(opacity)
    }
}

/// Label 的标题参与文字调节，SF Symbol 保持原来的颜色和不透明度。
struct TextOpacityLabelStyle: LabelStyle
{
    func makeBody(configuration: Configuration) -> some View
    {
        Label
        {
            configuration.title.appTextOpacity()
        }
        icon:
        {
            configuration.icon
        }
        .labelStyle(.titleAndIcon)
    }
}

extension View
{
    /// 仅用于 Text、TextField 或 Label 的 title，不用于含图标的混合容器。
    func appTextOpacity() -> some View
    {
        modifier(TextOpacityModifier())
    }

    /// 仅用于背景层，不用于整个卡片、按钮或页面。
    func componentBackgroundOpacity() -> some View
    {
        modifier(ComponentOpacityModifier())
    }
}
