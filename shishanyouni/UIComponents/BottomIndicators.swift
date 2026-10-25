import SwiftUI

/// 成绩、考试、空教室等页面共用的底部液态玻璃容器。
struct QueryBottomIndicatorBar<Content: View>: View
{
    @Environment(\.isInsideLiquidGlassSurface) private var isInsideSurface

    let content: Content
    let cornerRadius: CGFloat

    init(
        cornerRadius: CGFloat = 24,
        @ViewBuilder content: () -> Content
    )
    {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View
    {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .padding(10)
            .background { LiquidGlassBase(shape: shape, isInsideSurface: isInsideSurface) }
            .clipShape(shape)
            .optionalLiquidGlass(in: shape)
            .padding(.horizontal, 20)
            .padding(.bottom, 25)
    }
}

private struct QueryBottomIndicatorModifier: ViewModifier
{
    let cornerRadius: CGFloat

    func body(content: Content) -> some View
    {
        QueryBottomIndicatorBar(cornerRadius: cornerRadius)
        {
            content
        }
    }
}

extension View
{
    func queryBottomIndicatorBar(cornerRadius: CGFloat = 24) -> some View
    {
        modifier(QueryBottomIndicatorModifier(cornerRadius: cornerRadius))
    }
}

