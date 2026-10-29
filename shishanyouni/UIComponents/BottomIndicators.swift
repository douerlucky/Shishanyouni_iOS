import SwiftUI

/// 成绩、考试、空教室等页面共用的底部液态玻璃容器。
struct QueryBottomIndicatorBar<Content: View>: View
{
    let content: Content
    let cornerRadius: CGFloat?

    init(
        cornerRadius: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    )
    {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View
    {
        let shape = cornerRadius.map { AnyShape(RoundedRectangle(cornerRadius: $0, style: .continuous)) }
            ?? AnyShape(Capsule())

        content
            .padding(10)
            .clipShape(shape)
            .optionalLiquidGlass(in: shape, fallback: Color(uiColor: .secondarySystemBackground))
            .padding(.horizontal, 20)
            .padding(.bottom, 25)
    }
}

private struct QueryBottomIndicatorModifier: ViewModifier
{
    let cornerRadius: CGFloat?

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
    func queryBottomIndicatorBar(cornerRadius: CGFloat? = nil) -> some View
    {
        modifier(QueryBottomIndicatorModifier(cornerRadius: cornerRadius))
    }
}

