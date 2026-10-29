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

            result.append(FeatureSection(title: definition.title, features: ordered(matchingFeatures)))
            remaining.removeAll { definition.keys.contains($0.key) }
        }

        if !remaining.isEmpty
        {
            result.append(FeatureSection(title: "其他", features: ordered(remaining)))
        }

        return result
    }

    private func ordered(_ items: [HomeFeatureItem]) -> [HomeFeatureItem]
    {
        let byKey = Dictionary(uniqueKeysWithValues: items.map { ($0.key, $0) })
        return homeLayer.visibleCatalogKeys(from: items.map(\.key)).compactMap { byKey[$0] }
    }

    var body: some View
    {
        VStack(alignment: .leading, spacing: 18)
        {
            Text("全部功能")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .padding(.horizontal, 20)
                .appTextOpacity()

            VStack(alignment: .leading, spacing: 10)
            {
                Text("编辑后长按图标可在分类内拖动排序，点击加号可添加到主页；顺序会自动保存。")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .appTextOpacity()

            ForEach(sections)
            {
                section in
                VStack(alignment: .leading, spacing: 12)
                {
                    Text(section.title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .padding(.horizontal, 20)
                        .appTextOpacity()

                    HomeFeatureGridView(
                        features: section.features,
                        isEditing: isEditing,
                        kind: .catalog(favorites: Set(homeLayer.preferredKeys)),
                        onSelect: onSelect,
                        onAccessory: { homeLayer.add($0.key) },
                        onStartEditing: { isEditing = true },
                        onReorder: homeLayer.updateCatalogOrder
                    )
                    .frame(height: HomeFeatureGridView.height(for: section.features.count))
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 28)
        }
        .background(Color.clear)
    }
}
