import Combine
import SwiftUI
import UIKit

// 首页职责：
// 1. 在 allFeatures 定义所有入口及其跳转动作；
// 2. 通过 HomeLayer 选出首页常用入口；
// 3. 用两段连续的滚动叠层承载收藏和全部功能，避免分页器与嵌套滚动抢手势。

enum HomeMenuColor
{
    static let red1 = Color.adaptive(light: Color(red: 0.89, green: 0.24, blue: 0.22), dark: Color(red: 0.95, green: 0.40, blue: 0.38))
    static let red2 = Color.adaptive(light: Color(red: 0.80, green: 0.18, blue: 0.30), dark: Color(red: 0.88, green: 0.35, blue: 0.45))
    static let orange1 = Color.adaptive(light: Color(red: 0.95, green: 0.47, blue: 0.18), dark: Color(red: 0.98, green: 0.60, blue: 0.35))
    static let orange2 = Color.adaptive(light: Color(red: 0.90, green: 0.58, blue: 0.16), dark: Color(red: 0.94, green: 0.68, blue: 0.32))
    static let yellow1 = Color.adaptive(light: Color(red: 0.86, green: 0.73, blue: 0.16), dark: Color(red: 0.90, green: 0.78, blue: 0.30))
    static let yellow2 = Color.adaptive(light: Color(red: 0.72, green: 0.76, blue: 0.18), dark: Color(red: 0.78, green: 0.80, blue: 0.32))
    static let green1 = Color.adaptive(light: Color(red: 0.26, green: 0.69, blue: 0.31), dark: Color(red: 0.35, green: 0.75, blue: 0.40))
    static let green2 = Color.adaptive(light: Color(red: 0.15, green: 0.71, blue: 0.47), dark: Color(red: 0.28, green: 0.76, blue: 0.55))
    static let cyan1 = Color.adaptive(light: Color(red: 0.12, green: 0.70, blue: 0.74), dark: Color(red: 0.28, green: 0.78, blue: 0.80))
    static let cyan2 = Color.adaptive(light: Color(red: 0.13, green: 0.63, blue: 0.86), dark: Color(red: 0.30, green: 0.72, blue: 0.90))
    static let blue1 = Color.adaptive(light: Color(red: 0.20, green: 0.49, blue: 0.92), dark: Color(red: 0.38, green: 0.62, blue: 0.95))
    static let blue2 = Color.adaptive(light: Color(red: 0.30, green: 0.40, blue: 0.88), dark: Color(red: 0.45, green: 0.52, blue: 0.92))
    static let purple1 = Color.adaptive(light: Color(red: 0.50, green: 0.34, blue: 0.86), dark: Color(red: 0.60, green: 0.48, blue: 0.92))
    static let purple2 = Color.adaptive(light: Color(red: 0.69, green: 0.34, blue: 0.78), dark: Color(red: 0.78, green: 0.48, blue: 0.85))
}

enum HomeFeatureDestination
{
    case grades
    case exams
    case nanhuRun
    case physicalTest
    case physicalCalculator
    case allCourses
    case chooseCourse
    case bus
    case electricity
    case classroom
    case strategy
    case club
    case gis
    case library
    case libraryCatalog
    case itc
    case aiAssistant
    case debug

    var authorizationScope: FeatureAuthorizationScope?
    {
        switch self
        {
        case .grades: return .grades
        case .exams: return .exams
        case .nanhuRun: return .nanhuRun
        case .physicalTest: return .physicalTest
        case .allCourses: return .allCourses
        case .chooseCourse: return .chooseCourse
        case .electricity: return .electricity
        case .library: return .libraryReservation
        case .itc: return .itc
        default: return nil
        }
    }
}

/// 首页顶部的时钟/日期和在华农天数共用同一套液态玻璃卡片规格。
/// 固定高度和内边距后，两张卡片能保持顶边、底边对齐，避免内容变化时跳动。
struct HomeHeaderGlassCard<Content: View>: View
{
    let content: Content
    private let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

    /// 两张首页信息卡共用固定高度，内容只负责在卡片内排版。
    static var fixedHeight: CGFloat { 72 }

    init(@ViewBuilder content: () -> Content)
    {
        self.content = content()
    }

    var body: some View
    {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .frame(height: Self.fixedHeight, alignment: .center)
            .frame(maxWidth: .infinity)
            .clipShape(shape)
            .optionalLiquidGlass(
                in: shape,
                fallback: Color(uiColor: .secondarySystemBackground).opacity(0.24)
            )
    }
}


struct MenuGridItem: View
{
    let title: String
    let icon: String
    let color: Color
    var isEditing = false
    var onLongPress: (() -> Void)? = nil
    let action: () -> Void

    static let iconSize: CGFloat = 60

    var body: some View
    {
        VStack(spacing: 12)
        {
            Button(action: action)
            {
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundStyle(color)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .nativeGlassButtonStyle(
                shape: .roundedRectangle(radius: 16),
                fillsWidth: true,
                backgroundTint: color.opacity(0.18)
            )
            .controlSize(.regular)
            .frame(width: Self.iconSize, height: Self.iconSize)
            .accessibilityLabel(title)
            // 编辑时让系统集合视图接管拖动，图标不再竞争点击手势。
            .allowsHitTesting(!isEditing)

            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 34, alignment: .top)
                .appTextOpacity()
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4).onEnded { _ in onLongPress?() },
            including: isEditing ? .none : .all
        )
    }
}

// MARK: - 入学天数圆环

struct DaysRing: View
{
    let days: Int

    var body: some View
    {
        ZStack
        {
            // 底环
            Circle()
                .stroke(Color.green.opacity(0.15), lineWidth: 4)
                .frame(width: 48, height: 48)

            // 进度环（按一年365天算比例）
            Circle()
                .trim(from: 0, to: min(CGFloat(days) / 365, 1.0))
                .stroke(
                    Color.green.opacity(0.6),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 48, height: 48)
                .rotationEffect(.degrees(-90))

            // 中间数字 + 文字
            VStack(spacing: 1)
            {
                Text(String(days))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.primary)
                    .appTextOpacity()

                Text("天")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(.secondary)
                    .appTextOpacity()
            }
        }
    }
}

#Preview
{
    HomeView()
        .environmentObject(userInfo())
        .environmentObject(IAPStore.preview(hasActiveSubscription: false))
}
