import SwiftUI
import UIKit

/// 将“页面背景不透明度”映射到各个容器原本的基准透明度。
/// 0.35 是默认值，因此升级后现有卡片外观保持不变；用户只调背景滑块时，
/// 所有使用该函数的课表/日程卡片会同步变淡或变实，而不会影响文字。
func pagePanelOpacity(base: Double, setting: Double) -> Double
{
    base * min(max(setting / 0.35, 0), 1)
}

/// 四个主 Tab 共用的全屏背景。
///
/// 背景在安全区外统一铺满，图片裁剪规则也统一，避免不同页面因为
/// NavigationStack 或 List 的可用高度不同而出现位置、缩放不一致。
struct PageBackgroundView: View
{
    let image: UIImage?
    let isEnabled: Bool
    let opacity: Double
    /// 页面容器背景浓度。图片透明度和容器背景透明度必须分开，
    /// 否则调淡卡片时会把用户的背景图片也一起调淡。
    @AppStorage(PreferenceKey.pageBackgroundOpacity)
    private var pageBackgroundOpacity: Double = 0.35

    var body: some View
    {
        GeometryReader
        { proxy in
            ZStack
            {
                Color(uiColor: .systemGroupedBackground)
                    // 只叠加一层很淡的系统底色，给课表、日程、首页和“我的”
                    // 相同的液态玻璃底色观感；背景图片仍由上面的 opacity 单独控制。
                    .opacity(isEnabled ? pageBackgroundOpacity * 0.35 : 1)

                if isEnabled, let image
                {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .opacity(opacity)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
