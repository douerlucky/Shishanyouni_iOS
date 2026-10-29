import SwiftUI
import Testing
@testable import shishanyouni

/// 用无玻璃回退层检查像素 alpha；系统玻璃材质的实际外观仍需设备验收。
@MainActor
struct AppearanceOpacityTests
{
    @Test("背景全透明时，前景只受文字参数影响", arguments: [0.0, 0.4, 1.0])
    func transparentBackgroundKeepsForegroundIndependent(textOpacity: Double) throws
    {
        let image = try render(textOpacity: textOpacity, componentOpacity: 0)
        #expect(abs(try alpha(in: image, x: 30, y: 30) - textOpacity) < 0.02)
        #expect(try alpha(in: image, x: 4, y: 4) < 0.02)
    }

    @Test("文字全透明时，背景仍按组件参数显示", arguments: [0.0, 0.35, 1.0])
    func transparentTextKeepsBackgroundIndependent(componentOpacity: Double) throws
    {
        let image = try render(textOpacity: 0, componentOpacity: componentOpacity)
        #expect(abs(try alpha(in: image, x: 30, y: 30) - componentOpacity) < 0.02)
        #expect(abs(try alpha(in: image, x: 4, y: 4) - componentOpacity) < 0.02)
    }

    @Test("没有文字修饰的图标不随两个参数变淡", arguments: [0.0, 1.0])
    func iconKeepsItsOwnOpacity(opacity: Double) throws
    {
        let image = try render(textOpacity: opacity, componentOpacity: opacity, icon: true)
        #expect(try alpha(in: image, x: 30, y: 30) > 0.98)
    }

    private func render(textOpacity: Double, componentOpacity: Double, icon: Bool = false) throws -> CGImage
    {
        let suite = "AppearanceOpacityTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(textOpacity, forKey: PreferenceKey.textOpacity)
        defaults.set(componentOpacity, forKey: PreferenceKey.componentOpacity)
        defer { defaults.removePersistentDomain(forName: suite) }

        let content = Group
        {
            if icon { Color.green.frame(width: 20, height: 20) }
            else { Color.green.frame(width: 20, height: 20).appTextOpacity() }
        }
        .padding(20)
        .optionalLiquidGlass(enabled: false, in: Rectangle(), fallback: .red)
        .defaultAppStorage(defaults)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        return try #require(renderer.cgImage)
    }

    private func alpha(in image: CGImage, x: Int, y: Int) throws -> Double
    {
        let pixel = try #require(image.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)))
        var bytes = [UInt8](repeating: 0, count: 4)
        return try bytes.withUnsafeMutableBytes
        { buffer in
            let context = try #require(CGContext(
                data: buffer.baseAddress,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            context.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return Double(buffer[3]) / 255
        }
    }
}
