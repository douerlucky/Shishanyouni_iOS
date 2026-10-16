import SwiftUI
import UIKit

/// 第二层叠加页面中的分类目录。
///
/// 这个 View 只负责绘制目录内容，不创建自己的 ScrollView。
/// 滚动由首页的外层叠层 ScrollView 负责，避免同一页面嵌套纵向滚动。
struct AllFunctionView: View
{
    /// 全量功能目录；游客模式下会由 HomeView 预先过滤掉需要登录的入口。
    let features: [HomeFeatureItem]
    /// 首页常用入口的选择与排序状态，不在本 View 中重复保存一份。
    @ObservedObject var homeLayer: HomeLayer
    /// 和首页共用编辑状态：编辑时点击右上角绿色加号，非编辑时点击卡片进入功能。
    @Binding var isEditing: Bool
    /// 点击目录卡片后的路由回调；真正的导航状态仍由 HomeView 管理。
    let onSelect: (HomeFeatureItem) -> Void

    @AppStorage("scheduleContentOpacity") private var scheduleContentOpacity: Double = 1.0

    /// 每个分类复用同一组三列 Grid，避免为每个分类重复写布局代码。
    private let allFeaturesColumns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    /// 分类只保存稳定的功能 key；标题、图标和 action 仍由 HomeView.allFeatures 统一提供。
    private let categoryDefinitions: [(title: String, keys: [HomeFeatureKey])] = [
        ("学习教务", [.grades, .exams, .allCourses, .chooseCourse, .itc]),
        ("图书与自习", [.libraryCatalog, .library, .classroom]),
        ("运动健康", [.nanhuRun, .physicalTest, .physicalCalculator]),
        ("校园生活", [.electricity, .bus, .strategy, .club]),
    ]

    /// 未被分类的新功能会落到“其他”，避免新增入口后在首页目录中消失。
    private var sections: [FeatureSection]
    {
        var remaining = features
        var result: [FeatureSection] = []

        for definition in categoryDefinitions
        {
            let matchingFeatures = remaining.filter { definition.keys.contains($0.key) }
            guard !matchingFeatures.isEmpty else { continue }

            result.append(FeatureSection(title: definition.title, features: matchingFeatures))
            remaining.removeAll { definition.keys.contains($0.key) }
        }

        if !remaining.isEmpty
        {
            result.append(FeatureSection(title: "其他", features: remaining))
        }

        return result
    }

    var body: some View
    {
        VStack(alignment: .leading, spacing: 18)
        {
            Text("全部功能")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .padding(.horizontal, 20)
                .opacity(scheduleContentOpacity)

            VStack(alignment: .leading, spacing: 10)
            {
                Text("长按或点击右上角编辑按钮，点击图标右上角的加号，将常用功能添加到主页")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .opacity(scheduleContentOpacity)

            ForEach(sections)
            {
                section in
                VStack(alignment: .leading, spacing: 12)
                {
                    Text(section.title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .padding(.horizontal, 20)
                        .opacity(scheduleContentOpacity)

                    LazyVGrid(columns: allFeaturesColumns, spacing: 22)
                    {
                        ForEach(section.features) { feature in
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
                    .opacity(scheduleContentOpacity)
                }
            }
            .padding(.bottom, 28)
        }
        .background(Color.clear)
    }
}

private struct FeatureSection: Identifiable
{
    let title: String
    let features: [HomeFeatureItem]

    var id: String { title }
}
