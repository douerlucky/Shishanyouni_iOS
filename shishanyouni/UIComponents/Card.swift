import SwiftUI

/// 轻量液态玻璃卡片。内容布局和卡片材质分离，便于首页、日程和查询页复用。
struct LiquidGlassCard<Content: View>: View
{
    let cornerRadius: CGFloat
    let enabled: Bool
    let content: Content

    init(
        cornerRadius: CGFloat = 20,
        enabled: Bool = true,
        @ViewBuilder content: () -> Content
    )
    {
        self.cornerRadius = cornerRadius
        self.enabled = enabled
        self.content = content()
    }

    var body: some View
    {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .clipShape(shape)
            .optionalLiquidGlass(
                enabled: enabled,
                in: shape,
                fallback: Color(uiColor: .secondarySystemBackground)
            )
    }
}

