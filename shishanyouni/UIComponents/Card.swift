import SwiftUI

/// 轻量液态玻璃卡片。内容布局和卡片材质分离，便于首页、日程和查询页复用。
struct LiquidGlassCard<Content: View>: View
{
    @Environment(\.isInsideLiquidGlassSurface) private var isInsideSurface

    let cornerRadius: CGFloat
    let opacity: Double
    let enabled: Bool
    let content: Content

    init(
        cornerRadius: CGFloat = 20,
        opacity: Double = 0.34,
        enabled: Bool = true,
        @ViewBuilder content: () -> Content
    )
    {
        self.cornerRadius = cornerRadius
        self.opacity = opacity
        self.enabled = enabled
        self.content = content()
    }

    var body: some View
    {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background { LiquidGlassBase(shape: shape, isInsideSurface: isInsideSurface) }
            .overlay(shape.stroke(Color.white.opacity(opacity), lineWidth: 0.7))
            .clipShape(shape)
            .optionalLiquidGlass(enabled: enabled, in: shape)
    }
}

