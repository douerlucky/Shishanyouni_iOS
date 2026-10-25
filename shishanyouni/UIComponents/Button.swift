import SwiftUI

/// 所有主要蓝色操作共用系统蓝，保持课表和查询页面一致。
let appActionBlue = Color.blue

/// 统一操作按钮；即使位于玻璃容器内也允许玻璃，仍受全局开关控制。
/// 业务页面只传入颜色、图标和动作，不再各自拼接背景与圆角。
struct LiquidGlassCapsuleButton: View
{
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View
    {
        Button(action: action)
        {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .background(tint, in: Capsule())
        .clipShape(Capsule())
        .optionalLiquidGlass(allowsNesting: true, in: Capsule())
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
        LiquidGlassCapsuleButton(title: title, tint: .red, action: action)
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

/// 查询操作按钮。没有标题时会退化为圆形图标按钮。
struct SearchButton: View
{
    let title: String?
    let action: () -> Void

    init(_ title: String? = "搜索", action: @escaping () -> Void)
    {
        self.title = title
        self.action = action
    }

    var body: some View
    {
        Button(action: action)
        {
            HStack(spacing: 6)
            {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .bold))

                if let title
                {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: title == nil ? nil : .infinity)
            .frame(width: title == nil ? 42 : nil, height: 42)
        }
        .buttonStyle(.plain)
        .background(appActionBlue, in: title == nil ? AnyShape(Circle()) : AnyShape(Capsule()))
        .clipShape(title == nil ? AnyShape(Circle()) : AnyShape(Capsule()))
        .optionalLiquidGlass(allowsNesting: true, in: title == nil ? AnyShape(Circle()) : AnyShape(Capsule()))
    }
}

/// 用于前一天/后一天、前一周/后一周等操作的圆形按钮。
struct NextButton: View
{
    let systemImage: String
    let tint: Color
    let action: () -> Void
    var size: CGFloat = 42

    init(
        systemImage: String,
        tint: Color = appActionBlue,
        size: CGFloat = 34,
        action: @escaping () -> Void
    )
    {
        self.systemImage = systemImage
        self.tint = tint
        self.size = size
        self.action = action
    }

    var body: some View
    {
        Button(action: action)
        {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .background(tint, in: Circle())
        .clipShape(Circle())
        .optionalLiquidGlass(allowsNesting: true, in: Circle())
    }
}

