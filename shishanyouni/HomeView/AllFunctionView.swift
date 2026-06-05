import SwiftUI
import UIKit

struct AllFunctionView: View
{
    let features: [HomeFeatureItem]
    @ObservedObject var homeLayer: HomeLayer
    @Binding var isEditing: Bool
    let onBack: () -> Void
    let onSelect: (HomeFeatureItem) -> Void

    @AppStorage("scheduleContentOpacity") private var scheduleContentOpacity: Double = 1.0
    @AppStorage("enableLiquidGlassEffect") private var enableLiquidGlassEffect: Bool = false

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
