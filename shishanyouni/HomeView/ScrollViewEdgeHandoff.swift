import SwiftUI
import UIKit

/// 在 UIScrollView 到达边界后，把后续的同一根手指交给外层叠层。
///
/// 普通滚动仍由 UIScrollView 自己处理。手指按下后先允许 ScrollView 滚动，
/// 同一次拖动到达目标边界时，再把“越过边界”的剩余位移交给叠层；这比在
/// gestureRecognizerShouldBegin 里提前判断边界更可靠，因为按下瞬间通常还
/// 没有真正滚到最后一行。
struct ScrollViewEdgeHandoff: UIViewRepresentable
{
    enum Edge
    {
        case top
        case bottom
    }

    let edge: Edge
    let isEnabled: Bool
    let onChanged: (CGFloat) -> Void
    let onEnded: (_ translationHeight: CGFloat, _ velocityHeight: CGFloat) -> Void

    func makeCoordinator() -> Coordinator
    {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> AnchorView
    {
        let view = AnchorView()
        view.onMoveToWindow = { [weak coordinator = context.coordinator] view in
            DispatchQueue.main.async
            {
                coordinator?.attach(to: view)
            }
        }
        return view
    }

    func updateUIView(_ view: AnchorView, context: Context)
    {
        context.coordinator.parent = self
        context.coordinator.updateEnabledState()

        // SwiftUI 可能会先更新 representable，再把它插入 UIScrollView。
        // 下一轮 run loop 再尝试一次可以覆盖这两种生命周期顺序。
        DispatchQueue.main.async
        {
            context.coordinator.attach(to: view)
        }
    }

    final class AnchorView: UIView
    {
        var onMoveToWindow: ((UIView) -> Void)?

        override func didMoveToWindow()
        {
            super.didMoveToWindow()
            onMoveToWindow?(self)
        }
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate
    {
        var parent: ScrollViewEdgeHandoff
        weak var scrollView: UIScrollView?
        private weak var handoffPan: UIPanGestureRecognizer?
        private var didBeginHandoff = false
        private var handoffStartTranslation: CGFloat = 0
        private var originalBounces: Bool?
        private var originalScrollEnabled: Bool?

        init(parent: ScrollViewEdgeHandoff)
        {
            self.parent = parent
        }

        func attach(to anchor: UIView)
        {
            guard let scrollView = nearestScrollView(from: anchor) else { return }
            guard self.scrollView !== scrollView else
            {
                updateEnabledState()
                return
            }

            detach()
            self.scrollView = scrollView

            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.delegate = self
            pan.maximumNumberOfTouches = 1
            pan.cancelsTouchesInView = false
            scrollView.addGestureRecognizer(pan)

            // 两个 pan 同时观察同一次拖动：ScrollView 负责正常滚动，
            // 这个 pan 只在滚动过程中真正到达边界后才开始回调外层。
            // 不再使用 require(toFail:)，否则外层只能在手势开始前判断边界，
            // 三排内容就会出现“先滚到底、第二次才能打开”的问题。
            handoffPan = pan
            updateEnabledState()
        }

        func detach()
        {
            resetHandoffState()
            if let handoffPan
            {
                handoffPan.view?.removeGestureRecognizer(handoffPan)
            }
            handoffPan = nil
            scrollView = nil
        }

        func updateEnabledState()
        {
            handoffPan?.isEnabled = parent.isEnabled
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool
        {
            guard parent.isEnabled,
                  let scrollView,
                  let pan = gestureRecognizer as? UIPanGestureRecognizer
            else { return false }

            let velocity = pan.velocity(in: scrollView)
            guard abs(velocity.y) > abs(velocity.x), abs(velocity.y) > 0 else { return false }

            switch parent.edge
            {
            case .top:
                return velocity.y > 0
            case .bottom:
                return velocity.y < 0
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool
        {
            // 允许这个观察手势和 UIScrollView 自己的 pan 共存，才能在同一
            // 根手指拖动中等待 ScrollView 到达边界。
            otherGestureRecognizer === scrollView?.panGestureRecognizer
                || gestureRecognizer === scrollView?.panGestureRecognizer
        }

        @objc private func handlePan(_ pan: UIPanGestureRecognizer)
        {
            let translation = pan.translation(in: scrollView).y

            switch pan.state
            {
            case .began:
                didBeginHandoff = false
                handoffStartTranslation = translation
                disableBounceForCurrentGesture()
            case .changed:
                guard let scrollView else { return }

                if !didBeginHandoff, isAtTargetEdge(scrollView)
                {
                    didBeginHandoff = true
                    handoffStartTranslation = translation
                    freezeScrollViewAtEdge(scrollView)
                    parent.onChanged(0)
                }

                guard didBeginHandoff else { return }
                parent.onChanged(translation - handoffStartTranslation)
            case .ended, .cancelled:
                guard didBeginHandoff else
                {
                    resetHandoffState()
                    return
                }

                parent.onEnded(
                    translation - handoffStartTranslation,
                    pan.velocity(in: scrollView).y
                )
                resetHandoffState()
            case .failed:
                resetHandoffState()
            default:
                break
            }
        }

        private func isAtTargetEdge(_ scrollView: UIScrollView) -> Bool
        {
            switch parent.edge
            {
            case .top:
                scrollView.isAtTop
            case .bottom:
                scrollView.isAtBottom
            }
        }

        private func disableBounceForCurrentGesture()
        {
            guard let scrollView, originalBounces == nil else { return }
            originalBounces = scrollView.bounces
            scrollView.bounces = false
        }

        private func freezeScrollViewAtEdge(_ scrollView: UIScrollView)
        {
            guard originalScrollEnabled == nil else { return }

            // 到达边界后，原生 pan 不再参与当前手势；否则它仍可能在同一帧
            // 改 contentOffset，和叠层的 pullProgress 形成两个位移源。
            originalScrollEnabled = scrollView.isScrollEnabled
            scrollView.isScrollEnabled = false
        }

        private func resetHandoffState()
        {
            if let scrollView, let originalScrollEnabled
            {
                scrollView.isScrollEnabled = originalScrollEnabled
            }
            if let scrollView, let originalBounces
            {
                scrollView.bounces = originalBounces
            }
            originalScrollEnabled = nil
            originalBounces = nil
            didBeginHandoff = false
            handoffStartTranslation = 0
        }

        private func nearestScrollView(from view: UIView) -> UIScrollView?
        {
            var current: UIView? = view.superview
            while let candidate = current
            {
                if let scrollView = candidate as? UIScrollView
                {
                    return scrollView
                }
                current = candidate.superview
            }
            return nil
        }
    }
}

private extension UIScrollView
{
    var isAtTop: Bool
    {
        contentOffset.y <= -adjustedContentInset.top + 1
    }

    var isAtBottom: Bool
    {
        let minimumOffset = -adjustedContentInset.top
        let maximumOffset = max(
            minimumOffset,
            contentSize.height - bounds.height + adjustedContentInset.bottom
        )
        return contentOffset.y >= maximumOffset - 1
    }
}
