import SwiftUI
import UIKit

/// 四个主 Tab 共用的全屏背景。
///
/// 背景在安全区外统一铺满，图片裁剪规则也统一，避免不同页面因为
/// NavigationStack 或 List 的可用高度不同而出现位置、缩放不一致。
struct PageBackgroundView: View
{
    let image: UIImage?
    let isEnabled: Bool
    let opacity: Double
    var body: some View
    {
        GeometryReader
        { proxy in
            ZStack
            {
                Color(uiColor: .systemGroupedBackground)
                    // 只叠加一层很淡的系统底色，给课表、日程、首页和“我的”
                    // 相同的页面底色；不模拟玻璃浓度，背景图片仍独立控制。
                    .opacity(isEnabled ? 0.12 : 1)

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
