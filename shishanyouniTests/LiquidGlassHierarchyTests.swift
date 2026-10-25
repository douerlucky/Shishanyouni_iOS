import SwiftUI
import Testing
@testable import shishanyouni

/// 验证真正的玻璃边界，而不是按“父组件/子组件”名称禁用材质。
@MainActor
struct LiquidGlassHierarchyTests
{
    @Test("普通页面和纯色父容器不算玻璃")
    func ordinaryContentIsNotAGlassSurface()
    {
        let capture = Capture()
        render(Probe(capture: capture).background(Color.blue))
        #expect(capture.values.last == false)
    }

    @Test("独立组件允许使用单层玻璃")
    func standaloneComponentKeepsGlass()
    {
        let capture = Capture()
        render(Probe(capture: capture).optionalLiquidGlass(in: Capsule()))
        #expect(capture.values.last == LiquidGlassAvailability.isSupported)
    }

    @Test("未绘制玻璃的父组件不阻止内部独立玻璃")
    func disabledParentDoesNotSuppressStandaloneChild()
    {
        let plainCapture = Capture()
        render(Probe(capture: plainCapture).optionalLiquidGlass(enabled: false, in: Capsule()))
        #expect(plainCapture.values.last == false)

        let childCapture = Capture()
        render(
            Probe(capture: childCapture)
                .optionalLiquidGlass(in: Capsule())
                .optionalLiquidGlass(enabled: false, in: Capsule())
        )
        #expect(childCapture.values.last == LiquidGlassAvailability.isSupported)
    }

    @Test("真实玻璃父层级的标记可穿过无玻璃组件继续传播")
    func existingSurfaceIsPreserved()
    {
        let capture = Capture()
        render(
            Probe(capture: capture)
                .optionalLiquidGlass(enabled: false, in: Capsule())
                .environment(\.isInsideLiquidGlassSurface, true)
        )
        #expect(capture.values.last == true)
    }

    @Test("共享卡片和查询栏只在实际启用玻璃时建立边界")
    func sharedContainersMarkTheirGlassContent()
    {
        let cardCapture = Capture()
        render(LiquidGlassCard { Probe(capture: cardCapture) })
        #expect(cardCapture.values.last == LiquidGlassAvailability.isSupported)

        let queryCapture = Capture()
        render(QueryBottomIndicatorBar { Probe(capture: queryCapture) })
        #expect(queryCapture.values.last == LiquidGlassAvailability.isSupported)

        let toolbarCapture = Capture()
        render(Probe(capture: toolbarCapture).glassBackground())
        #expect(toolbarCapture.values.last == LiquidGlassAvailability.isSupported)
    }

    @Test("Sheet 是独立界面，内部单层玻璃不受呈现来源影响")
    func presentationStartsANewSurfaceContext()
    {
        let plainCapture = Capture()
        render(
            Probe(capture: plainCapture)
                .environment(\.isInsideLiquidGlassSurface, false)
                .environment(\.isInsideLiquidGlassSurface, true)
        )
        #expect(plainCapture.values.last == false)

        let glassCapture = Capture()
        render(
            Probe(capture: glassCapture)
                .optionalLiquidGlass(in: Capsule())
                .environment(\.isInsideLiquidGlassSurface, false)
                .environment(\.isInsideLiquidGlassSurface, true)
        )
        #expect(glassCapture.values.last == LiquidGlassAvailability.isSupported)
    }

    @Test("全局关闭玻璃后不会新增玻璃边界")
    func globalSettingDisablesGlass()
    {
        let capture = Capture()
        render(
            Probe(capture: capture)
                .optionalLiquidGlass(allowsNesting: true, in: Capsule())
                .glassBackground(),
            glassEnabled: false
        )
        #expect(capture.values.last == false)
    }

    @Test("允许按钮叠放也不能绕过当前组件的关闭开关")
    func nestedExceptionRespectsLocalSetting()
    {
        let capture = Capture()
        render(
            Probe(capture: capture)
                .optionalLiquidGlass(enabled: false, allowsNesting: true, in: Capsule())
        )
        #expect(capture.values.last == false)
    }

    private func render(_ view: some View, glassEnabled: Bool = true)
    {
        let suiteName = "LiquidGlassHierarchyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(glassEnabled, forKey: PreferenceKey.enableLiquidGlassEffect)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let renderer = ImageRenderer(
            content: view
                .defaultAppStorage(defaults)
                .frame(width: 160, height: 100)
        )
        #expect(renderer.uiImage != nil)
    }

    private final class Capture
    {
        var values: [Bool] = []
    }

    private struct Probe: View
    {
        @Environment(\.isInsideLiquidGlassSurface) private var isInsideSurface
        let capture: Capture

        var body: some View
        {
            capture.values.append(isInsideSurface)
            return Color.clear
        }
    }
}
