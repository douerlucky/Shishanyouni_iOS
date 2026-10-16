import SwiftUI
import UIKit

/// 日程和校历使用同一套月份切换手势：左滑下个月，右滑上个月。
struct MonthSwipeGesture: ViewModifier
{
    let onSwipe: (Int) -> Void

    func body(content: Content) -> some View
    {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 28)
                .onEnded
                { value in
                    let horizontal = value.translation.width
                    let vertical = value.translation.height
                    guard abs(horizontal) > 48,
                          abs(horizontal) > abs(vertical) * 1.25
                    else { return }

                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onSwipe(horizontal < 0 ? 1 : -1)
                }
        )
    }
}

extension View
{
    func monthSwipe(_ onSwipe: @escaping (Int) -> Void) -> some View
    {
        modifier(MonthSwipeGesture(onSwipe: onSwipe))
    }
}

