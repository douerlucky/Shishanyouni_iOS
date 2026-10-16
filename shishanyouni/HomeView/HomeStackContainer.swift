import SwiftUI
import UIKit

/// 首页的两层结构：第一层是普通 ScrollView，第二层是从底部覆盖上来的功能目录。
///
/// 第一层滚到底后，继续上滑会把拖动交给第二层，渐进展开（上层模糊变暗、
/// 下层缓缓浮现，类似 Apple Watch 智能叠放 / 淘宝下拉二楼）；第二层顶部
/// 继续下拉可以收回。底部箭头只是视觉提示。
///
/// 手势部分由 ScrollViewEdgeHandoff 使用 UIKit 的公开手势代理完成。
struct HomeStackContainer<FavoriteContent: View, AllFunctionsContent: View>: View
{
    let favoriteContent: FavoriteContent
    let allFunctionsContent: AllFunctionsContent

    @State private var page = 0
    @State private var pullProgress: CGFloat = 0
    @State private var hasTriggeredHaptic = false
    /// 回退叠层时，先把首页 ScrollView 无动画准备到顶部，避免它在
    /// 叠层已经收回后才从底部弹回顶部。
    @State private var favoritesTopResetToken = 0
    @State private var isPreparingFavoritesReturn = false
    @State private var favoritesReturnLockToken = 0
    @AppStorage(PreferenceKey.enableLiquidGlassEffect)
    private var liquidGlassEnabled: Bool = true
    @AppStorage(PreferenceKey.pageBackgroundOpacity)
    private var pageBackgroundOpacity: Double = 0.35

    init(
        @ViewBuilder favoriteContent: () -> FavoriteContent,
        @ViewBuilder allFunctionsContent: () -> AllFunctionsContent
    )
    {
        self.favoriteContent = favoriteContent()
        self.allFunctionsContent = allFunctionsContent()
    }

    private var revealAmount: CGFloat
    {
        // 下拉收回时 pullProgress 会从 1 逐渐回到 0，第一层也要同步变清晰。
        pullProgress
    }

    var body: some View
    {
        GeometryReader
        { proxy in
            stackBody(size: proxy.size)
        }
    }

    /// 第一层的滚动内容单独拆成一个表达式，避免和外层一长串 modifier 链一起
    /// 让编译器类型检查超时（Swift 对超长链式 modifier 的类型推断是组合爆炸的）。
    ///
    /// HomeStackContainer 本身是放在 NavigationStack 的 Tab 页面里使用的，
    /// 导航栏下方的顶部安全区已经由系统自动处理，不需要再手动补一次。
    private func favoritesScrollContent(size: CGSize) -> some View
    {
        // 内容按自身自然高度渲染，不强制撑满 size.height——如果强制撑满，
        // 内容实际高度比撑出来的高度短的那段会被当成"正常可滚动内容"，
        // 用户得先滑过这段空白才能真正到达边界，表现就是"看起来已经到底
        // 却毫无反应"。
        ScrollViewReader
        { proxy in
            ScrollView(.vertical)
        {
                Color.clear
                    .frame(height: 1)
                    .id("home-favorites-top")

                favoriteContent
                    .overlay
                    {
                        ScrollViewEdgeHandoff(
                            edge: .bottom,
                            isEnabled: page == 0 && !isPreparingFavoritesReturn,
                            onChanged: { translationHeight in
                                updatePullProgress(
                                    forTranslationHeight: translationHeight,
                                    containerHeight: size.height
                                )
                            },
                            onEnded: { translationHeight, velocityHeight in
                                finishPull(
                                    translationHeight: translationHeight,
                                    velocityHeight: velocityHeight,
                                    containerHeight: size.height
                                )
                            }
                        )
                        .frame(width: 1, height: 1)
                    }
            }
            .onChange(of: favoritesTopResetToken)
            { _ in
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction)
                {
                    proxy.scrollTo("home-favorites-top", anchor: .top)
                }
            }
        }
        .scrollIndicators(.hidden)
        .modifier(HomeStackScrollBounceBehavior())
        .modifier(HomeStackScrollEdgeEffect())
        .allowsHitTesting(page == 0 && !isPreparingFavoritesReturn)
    }

    private func stackBody(size: CGSize) -> some View
    {
        ZStack(alignment: .top)
        {
            favoritesScrollContent(size: size)
                .opacity(1 - revealAmount * 0.16)
                .blur(radius: revealAmount * 8)

            if page == 0, pullProgress == 0
            {
                VStack
                {
                    Spacer()
                    HStack
                    {
                        Spacer()
                        pullUpCue
                        Spacer()
                    }
                        .frame(height: 84)
                        .allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity, minHeight: size.height)
                .offset(y: 24)
            }

            // 第二层始终留在层级中，只通过 offset / opacity 隐藏。
            // 这样快速甩动时也会从当前进度连续补完，不会因为条件插入直接闪现。
            allFunctionsLayer(size: size)

            if page == 1, pullProgress == 1
            {
                VStack
                {
                    HStack
                    {
                        Spacer()
                        returnCue
                        Spacer()
                    }
                        .frame(height: 64)
                        .allowsHitTesting(false)
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: size.height)
            }
        }
        .contentShape(Rectangle())
        .accessibilityIdentifier("homeFavoritesScroll")
    }

    /// 第一层滚到底后，继续上滑的手指位移映射成展开进度。
    private func updatePullProgress(
        forTranslationHeight translationHeight: CGFloat,
        containerHeight: CGFloat
    )
    {
        guard page == 0 else { return }

        let targetProgress = min(
            max(-translationHeight / max(containerHeight, 1), 0),
            1
        )

        // 拖动阶段不要给每一个手势采样点启动动画：那会让多个弹簧相互
        // 追赶，表现成上下抖动。这里保持一一对应，松手后再统一吸附。
        pullProgress = targetProgress

        // haptic 要在真正会触发切换的那个阈值（0.5，和 finishPull 的判断
        // 一致）响一次，而不是非要拖到 1 才响——用户体感上"震动=这时候
        // 松手就会展开"，和 finishPull 的实际行为对应起来。
        if targetProgress >= 0.5, !hasTriggeredHaptic
        {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            hasTriggeredHaptic = true
        }
    }

    /// 第二层顶部继续下拉的手指位移映射成收回进度。
    private func updateReturnProgress(
        forTranslationHeight translationHeight: CGFloat,
        containerHeight: CGFloat
    )
    {
        guard page == 1 else { return }

        if !isPreparingFavoritesReturn
        {
            isPreparingFavoritesReturn = true
            favoritesTopResetToken &+= 1
        }

        let returnProgress = min(
            max(translationHeight / max(containerHeight, 1), 0),
            1
        )
        let targetProgress = 1 - returnProgress

        // 返回阶段同样直接跟手，最终状态由 finishPull 的一次弹簧动画决定。
        pullProgress = targetProgress

        if returnProgress >= 0.5, !hasTriggeredHaptic
        {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            hasTriggeredHaptic = true
        }
    }

    private func finishPull(
        translationHeight: CGFloat = 0,
        velocityHeight: CGFloat = 0,
        containerHeight: CGFloat
    )
    {
        let isFastUpwardFlick = page == 0 && velocityHeight < -650
        let distance = max(containerHeight, 1)
        let rawProgress = page == 0
            ? min(max(-translationHeight / distance, 0), 1)
            : 1 - min(max(translationHeight / distance, 0), 1)

        // 用原始手势进度决定是否吸附，不能依赖正在追踪目标的
        // pullProgress，否则快速松手时视觉弹簧还没追上就会被误判为没有拖动。
        guard page == 1 || rawProgress > 0 || isFastUpwardFlick else { return }

        // 松手时只要求拖过一半（0.5），不要求精确拖到接近 1 才算数——
        // 这是下拉刷新、滑动删除这类系统交互常见的做法：过了一半就直接
        // 吸附到终态，不够一半才弹回去，不需要手指精确停在某个临界点。
        var shouldKeepFavoritesLocked = false

        withAnimation(.interactiveSpring(response: 0.62, dampingFraction: 0.86, blendDuration: 0.2))
        {
            if page == 0
            {
                let dragProgress = min(max(-translationHeight / distance, 0), 1)
                let shouldOpen = dragProgress >= 0.5 || isFastUpwardFlick

                if shouldOpen
                {
                    if !hasTriggeredHaptic
                    {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    page = 1
                    pullProgress = 1
                }
                else
                {
                    pullProgress = 0
                }
            }
            else if page == 1
            {
                let dragProgress = min(max(translationHeight / distance, 0), 1)
                let isFastDownwardFlick = velocityHeight > 650
                let shouldClose = 1 - dragProgress <= 0.5 || isFastDownwardFlick

                if shouldClose
                {
                    if !hasTriggeredHaptic
                    {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    page = 0
                    pullProgress = 0
                    shouldKeepFavoritesLocked = true
                }
                else
                {
                    pullProgress = 1
                }
            }
        }

        hasTriggeredHaptic = false

        if shouldKeepFavoritesLocked
        {
            // page 已经回到首页，但动画和原生手势还可能有尾巴；保持首页
            // ScrollView 不可交互，避免用户继续下拉把内容拉出安全区。
            favoritesReturnLockToken &+= 1
            let token = favoritesReturnLockToken
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.72)
            {
                guard favoritesReturnLockToken == token else { return }
                isPreparingFavoritesReturn = false
            }
        }
        else
        {
            isPreparingFavoritesReturn = false
        }
    }

    /// 第二层的滚动内容单独拆成一个表达式，避免和外层一长串 modifier 链一起
    /// 让编译器类型检查超时（Swift 对超长链式 modifier 的类型推断是组合爆炸的）。
    private func allFunctionsScrollContent(size: CGSize) -> some View
    {
        ScrollView(.vertical)
        {
            allFunctionsContent
                .overlay
                {
                    ScrollViewEdgeHandoff(
                        edge: .top,
                        isEnabled: page == 1,
                        onChanged: { translationHeight in
                            updateReturnProgress(
                                forTranslationHeight: translationHeight,
                                containerHeight: size.height
                            )
                        },
                        onEnded: { translationHeight, velocityHeight in
                            finishPull(
                                translationHeight: translationHeight,
                                velocityHeight: velocityHeight,
                                containerHeight: size.height
                            )
                        }
                    )
                    .frame(width: 1, height: 1)
                }
                .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
        .modifier(HomeStackScrollBounceBehavior())
        .modifier(HomeStackScrollEdgeEffect())
    }

    private func allFunctionsLayer(size: CGSize) -> some View
    {
        let panelShape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        return allFunctionsScrollContent(size: size)
            // 先让 ScrollView 填满，再由最终 frame 统一计算四周边距，保证
            // 真机上“全部功能”始终覆盖整个可用区域。
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // “全部功能”本身就是第二层液态玻璃：使用很淡的材料底，
            // 让首页图片持续透出；开关关闭时只保留轻微的材料背景。
            .background
            {
                panelShape
                    .fill(.ultraThinMaterial)
                    .opacity(pageBackgroundOpacity)
                    .optionalLiquidGlass(enabled: liquidGlassEnabled, in: panelShape)
            }
            .clipShape(panelShape)
            .padding(.horizontal, 8)
            .padding(.top, 12)
            .frame(width: size.width, height: size.height, alignment: .top)
            .offset(y: (1 - pullProgress) * size.height)
            .opacity(min(pullProgress * 1.25, 1))
            .blur(radius: (1 - pullProgress) * 3)
            // 下拉收回过程中仍要保持命中测试，否则 progress 下降到 0.98
            // 时会提前取消当前手势。
            .allowsHitTesting(page == 1)
    }

    private var pullUpCue: some View
    {
        Image(systemName: "chevron.up")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.thinMaterial, in: Capsule())
            .optionalLiquidGlass(in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 0.5)
            )
            .accessibilityLabel("向上拖动查看全部功能")
    }

    private var returnCue: some View
    {
        Image(systemName: "chevron.down")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.thinMaterial, in: Capsule())
            .optionalLiquidGlass(in: Capsule())
            .accessibilityLabel("向下拖动返回常用功能")
    }
}

private struct HomeStackScrollBounceBehavior: ViewModifier
{
    func body(content: Content) -> some View
    {
        if #available(iOS 16.4, *)
        {
            content.scrollBounceBehavior(.always, axes: .vertical)
        }
        else
        {
            content
        }
    }
}

private struct HomeStackScrollEdgeEffect: ViewModifier
{
    func body(content: Content) -> some View
    {
        if #available(iOS 26.0, *)
        {
            content.scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
        }
        else
        {
            content
        }
    }
}
