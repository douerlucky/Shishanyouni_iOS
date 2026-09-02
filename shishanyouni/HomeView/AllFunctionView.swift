import SwiftUI
import UIKit

/// 首页向上翻页后的「全部功能」目录。
///
/// 功能本身的标题、图标和跳转动作由 `HomeView.allFeatures` 统一提供；
/// 这里仅负责三列展示，以及把“添加到首页”的操作交给 `HomeLayer` 持久化。
struct AllFunctionView: View
{
    /// 全量功能目录；游客模式下会由 `HomeView` 预先过滤掉需要登录的入口。
    let features: [HomeFeatureItem]
    /// 首页常用入口的选择与排序状态，不在本 View 中重复保存一份。
    @ObservedObject var homeLayer: HomeLayer
    /// 和首页共用编辑状态：编辑时点击右上角绿色加号，非编辑时点击卡片进入功能。
    @Binding var isEditing: Bool
    /// 回到首页概览页（由 HomeView 的纵向分页器执行）。
    let onBack: () -> Void
    /// 点击目录卡片后的路由回调；真正的导航状态仍由 HomeView 管理。
    let onSelect: (HomeFeatureItem) -> Void

    @AppStorage("scheduleContentOpacity") private var scheduleContentOpacity: Double = 1.0
    @AppStorage("enableLiquidGlassEffect") private var enableLiquidGlassEffect: Bool = false

    /// 全部功能页使用纯 SwiftUI 的固定三列目录 Grid。
    private let allFeaturesColumns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    var body: some View
    {
        ScrollView
        {
            VStack(alignment: .leading, spacing: 18)
            {
                VStack(alignment: .leading, spacing: 10)
                {
                    HStack
                    {
                        Spacer()

                        Button(action: onBack)
                        {
                            HomeFloatingPagerButton(direction: "chevron.up", enableLiquidGlassEffect: enableLiquidGlassEffect)
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }

                    Text("全部功能")
                        .font(.system(size: 26, weight: .bold, design: .rounded))

                    HStack(alignment: .center)
                    {
                        Text("长按或点击右上角编辑按钮，进入编辑模式，点击图标右上角的加号按钮，将需要常用到的功能添加到主页")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .opacity(scheduleContentOpacity)

                // 这是“全部功能”目录 Grid，不是首页可拖拽的常用功能 Grid。
                LazyVGrid(columns: allFeaturesColumns, spacing: 22)
                {
                    ForEach(features) { feature in
                        EditableHomeFeatureItem(
                            feature: feature,
                            isEditing: isEditing,
                            accessoryIcon: homeLayer.contains(feature.key) ? nil : "plus.circle.fill",
                            accessoryColor: .green,
                            action: {
                                guard !isEditing else { return }
                                onSelect(feature)
                            },
                            // 加号只改 HomeLayer 的 key 列表；首页会因 @Published 自动刷新。
                            accessoryAction: {
                                homeLayer.add(feature.key)
                            },
                            onLongPress: {
                                guard !isEditing else { return }
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                isEditing = true
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
                .opacity(scheduleContentOpacity)
            }
        }
        .background(Color.clear)
    }
}
