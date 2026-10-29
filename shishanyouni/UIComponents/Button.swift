import SwiftUI

/// 所有主要蓝色操作共用系统蓝，保持课表和查询页面一致。
let appActionBlue = Color.blue

enum QueryControlMetrics
{
    static let height: CGFloat = 42
}

/// 将业务端的形状选择映射到系统 ButtonBorderShape，兼容最低 iOS 16。
enum AppButtonShape
{
    case capsule
    case circle
    case roundedRectangle(radius: CGFloat)

    static var roundedRectangle: Self { .roundedRectangle(radius: 12) }

    var borderShape: ButtonBorderShape
    {
        switch self
        {
        case .capsule: return .capsule
        case .circle:
            if #available(iOS 17.0, *) { return .circle }
            return .capsule
        case .roundedRectangle(let radius):
            if #available(iOS 17.0, *) { return .roundedRectangle(radius: radius) }
            return .roundedRectangle
        }
    }
}

/// 只选择 Apple 自带样式；不重画底板、不改按压行为，也不给整个按钮叠加 opacity。
private struct NativeGlassButtonStyle: PrimitiveButtonStyle
{
    let prominent: Bool
    let shape: AppButtonShape
    let fillsWidth: Bool
    let backgroundTint: Color?
    @AppStorage(PreferenceKey.enableLiquidGlassEffect) private var glassEnabled = true

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View
    {
        if #available(iOS 26.0, *), glassEnabled
        {
            glassButton(configuration)
                .buttonBorderShape(shape.borderShape)
                .buttonSizing(fillsWidth ? .flexible : .fitted)
                .environment(\.isInsideLiquidGlassSurface, true)
        }
        else
        {
            borderedButton(configuration)
                .buttonBorderShape(shape.borderShape)
        }
    }

    @available(iOS 26.0, *)
    @ViewBuilder
    private func glassButton(_ configuration: Configuration) -> some View
    {
        if prominent
        {
            Button(configuration)
                .buttonStyle(.glassProminent)
                .tint(backgroundTint ?? appActionBlue)
        }
        else if #available(iOS 26.1, *)
        {
            Button(configuration)
                .buttonStyle(.glass(.regular.tint(backgroundTint)))
        }
        else if let backgroundTint
        {
            Button(configuration)
                .buttonStyle(.glass)
                .tint(backgroundTint)
        }
        else
        {
            Button(configuration).buttonStyle(.glass)
        }
    }

    @ViewBuilder
    private func borderedButton(_ configuration: Configuration) -> some View
    {
        if prominent
        {
            Button(configuration)
                .buttonStyle(.borderedProminent)
                .tint(backgroundTint ?? appActionBlue)
        }
        else if let backgroundTint
        {
            Button(configuration)
                .buttonStyle(.bordered)
                .tint(backgroundTint)
        }
        else
        {
            Button(configuration).buttonStyle(.bordered)
        }
    }
}

extension View
{
    /// 页面内独立操作使用原生玻璃按钮；系统工具栏、菜单、Alert 不需要再套一层。
    func nativeGlassButtonStyle(
        prominent: Bool = false,
        shape: AppButtonShape = .capsule,
        fillsWidth: Bool = false,
        backgroundTint: Color? = nil
    ) -> some View
    {
        buttonStyle(NativeGlassButtonStyle(
            prominent: prominent,
            shape: shape,
            fillsWidth: fillsWidth,
            backgroundTint: backgroundTint
        ))
    }
}

/// 全宽操作的尺寸必须放进 label，不能仅把背景铺在 Button 外面。
struct LiquidGlassCapsuleButton: View
{
    let title: String
    let tint: Color
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View
    {
        Button(role: role, action: action)
        {
            Text(title)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .appTextOpacity()
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .nativeGlassButtonStyle(prominent: true, fillsWidth: true, backgroundTint: tint)
        .tint(tint)
        .controlSize(.large)
    }
}

struct CancelButton: View
{
    let title: String
    let action: () -> Void

    init(_ title: String = "取消", action: @escaping () -> Void)
    {
        self.title = title
        self.action = action
    }

    var body: some View
    {
        LiquidGlassCapsuleButton(title: title, tint: .red, role: .cancel, action: action)
    }
}

struct AcceptButton: View
{
    let title: String
    let action: () -> Void

    init(_ title: String = "确定", action: @escaping () -> Void)
    {
        self.title = title
        self.action = action
    }

    var body: some View
    {
        LiquidGlassCapsuleButton(title: title, tint: appActionBlue, action: action)
    }
}

/// 查询栏只显示圆形搜索图标；传入的标题仅供 VoiceOver 使用。
struct SearchButton: View
{
    let accessibilityTitle: String
    let action: () -> Void

    init(_ accessibilityTitle: String = "搜索", action: @escaping () -> Void)
    {
        self.accessibilityTitle = accessibilityTitle
        self.action = action
    }

    var body: some View
    {
        NextButton(systemImage: "magnifyingglass", size: QueryControlMetrics.height, action: action)
            .accessibilityLabel(accessibilityTitle)
    }
}

/// 用于前一天/后一天、前一周/后一周等操作的原生圆形按钮。
struct NextButton: View
{
    let systemImage: String
    let tint: Color
    let action: () -> Void
    let size: CGFloat
    let prominent: Bool

    init(
        systemImage: String,
        tint: Color = appActionBlue,
        size: CGFloat = 34,
        prominent: Bool = true,
        action: @escaping () -> Void
    )
    {
        self.systemImage = systemImage
        self.tint = tint
        self.size = size
        self.prominent = prominent
        self.action = action
    }

    var body: some View
    {
        Button(action: action)
        {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(prominent ? .white : tint)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .nativeGlassButtonStyle(
            prominent: prominent,
            shape: .circle,
            fillsWidth: true,
            backgroundTint: prominent ? tint : nil
        )
        .tint(tint)
        .controlSize(.mini)
        .frame(width: size, height: size)
    }
}

