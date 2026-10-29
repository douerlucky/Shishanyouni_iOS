import SwiftUI
import Testing
@testable import shishanyouni

/// 仅检查布局；真实点击与按压反馈需要在设备上验收。
@MainActor
struct ActionButtonLayoutTests
{
    @Test("主要文字按钮填满父容器提供的宽度", arguments: [false, true])
    func textButtonsUseAvailableWidth(glassEnabled: Bool) throws
    {
        for view in [
            AnyView(AcceptButton("确定") {}),
            AnyView(CancelButton("取消") {}),
        ]
        {
            let size = try renderedSize(of: view, proposedWidth: 320, glassEnabled: glassEnabled)
            #expect(abs(size.width - 320) < 0.5)
            #expect(size.height >= 44)
        }
    }

    @Test("圆形翻页和无标题搜索保持紧凑尺寸", arguments: [false, true])
    func iconButtonsKeepTheirSize(glassEnabled: Bool) throws
    {
        for side: CGFloat in [26, 28, 34, 42]
        {
            let next = try renderedSize(of: NextButton(systemImage: "chevron.right", size: side) {}, proposedWidth: 320, glassEnabled: glassEnabled)
            #expect(abs(next.width - side) < 0.5)
            #expect(abs(next.height - side) < 0.5)
        }

        let search = try renderedSize(of: SearchButton {}, proposedWidth: 320, glassEnabled: glassEnabled)
        #expect(abs(search.width - QueryControlMetrics.height) < 0.5)
        #expect(abs(search.height - QueryControlMetrics.height) < 0.5)
    }

    @Test("共用圆形按钮与直接使用官方 Liquid Glass 样式的尺寸和轮廓一致", arguments: ["minus", "plus", "chevron.left", "chevron.left.2"])
    func circularButtonMatchesOfficialStyle(symbol: String) throws
    {
        guard #available(iOS 26.0, *) else { return }
        for side: CGFloat in [26, 28, 32, 34, 42]
        {
            let image = try renderedImage(
                of: NextButton(systemImage: symbol, size: side) {}.padding(12),
                proposedWidth: side + 24,
                glassEnabled: true
            )
            let reference = Button(action: {})
            {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .buttonSizing(.flexible)
            .tint(appActionBlue)
            .controlSize(.mini)
            .frame(width: side, height: side)
            .padding(12)
            let referenceImage = try renderedImage(of: reference, proposedWidth: side + 24, glassEnabled: true)
            #expect(image.width == referenceImage.width && image.height == referenceImage.height)
            // 不假设系统材质的固定 alpha，只与同环境下的官方控件作比较。
            for point in [(13, 13), (10, 12 + Int(side / 2)), (13, 12 + Int(side / 2))]
            {
                let actual = try alpha(in: image, x: point.0, y: point.1)
                let expected = try alpha(in: referenceImage, x: point.0, y: point.1)
                #expect(abs(actual - expected) < 0.02)
            }
        }
    }

    @Test("收起周数栏的非强调按钮也使用同一个圆形底板")
    func weekCollapseButtonIsCircular() throws
    {
        let image = try renderedImage(
            of: NextButton(systemImage: "chevron.down", tint: .secondary, size: 32, prominent: false) {},
            proposedWidth: 320,
            glassEnabled: false
        )
        #expect(image.width == 32 && image.height == 32)
    }

    @Test("成绩和考试底栏默认使用胶囊，不影响空教室显式选择的圆角形状")
    func queryBarDefaultsToCapsule() throws
    {
        let image = try renderedImage(
            of: QueryBottomIndicatorBar { Color.clear.frame(width: 280, height: 42) },
            proposedWidth: 340,
            glassEnabled: false
        )
        #expect(image.width == 340 && image.height == 87)
        #expect(try alpha(in: image, x: 34, y: 3) < 0.02)
        #expect(try alpha(in: image, x: 21, y: 31) > 0.98)
    }

    @Test("长数据源名称、学期和圆形查询保持一行等高", arguments: [false, true])
    func queryControlsShareHeight(glassEnabled: Bool) throws
    {
        for width: CGFloat in [280, 320]
        {
            let row = HStack(spacing: 8)
            {
                DataSourceSelector(selection: .constant(TestSource.academic), fontSize: 13)
                SemesterSelector(title: "26-27 · 一", action: {})
                SearchButton("查询") {}
            }
            .frame(width: width)
            let size = try renderedSize(of: row, proposedWidth: width, glassEnabled: glassEnabled)
            #expect(abs(size.width - width) < 0.5)
            #expect(abs(size.height - QueryControlMetrics.height) < 0.5)
        }
    }

    @Test("教学楼选择与查询按钮保持相同高度", arguments: [false, true])
    func buildingSelectorSharesQueryHeight(glassEnabled: Bool) throws
    {
        let row = HStack(spacing: 8)
        {
            TeachingBuildingSelector(title: "三教 A 区", action: {})
            SearchButton {}
        }
        .frame(width: 240)
        let size = try renderedSize(of: row, proposedWidth: 240, glassEnabled: glassEnabled)
        #expect(abs(size.width - 240) < 0.5)
        #expect(abs(size.height - QueryControlMetrics.height) < 0.5)
    }

    @Test("授权操作保持横排，按钮高度使用同一系统规格", arguments: [false, true])
    func authorizationButtonsStayInOneRow(glassEnabled: Bool) throws
    {
        let buttons = HStack(spacing: 12)
        {
            CancelButton {}
            AcceptButton("我已阅读并同意授权") {}
        }
        .frame(width: 320)
        let size = try renderedSize(of: buttons, proposedWidth: 320, glassEnabled: glassEnabled)
        #expect(abs(size.width - 320) < 0.5)
        #expect(size.height >= 44 && size.height <= 64)
    }

    @Test("首页入口复用按钮后仍可完整放入收藏单元格", arguments: [false, true])
    func homeFeatureFitsCell(glassEnabled: Bool) throws
    {
        let view = MenuGridItem(title: "全校课程查询", icon: "books.vertical", color: .blue) {}
        let size = try renderedSize(of: view, proposedWidth: 96, glassEnabled: glassEnabled)
        #expect(abs(size.width - 96) < 0.5)
        #expect(MenuGridItem.iconSize == 60)
        #expect(size.height >= MenuGridItem.iconSize + 12 + 34)
        // 收藏单元格高 126，UIHostingConfiguration 上下各留 8。
        #expect(size.height <= 110)
    }

    private func renderedSize(of view: some View, proposedWidth: CGFloat, glassEnabled: Bool) throws -> CGSize
    {
        let image = try renderedImage(of: view, proposedWidth: proposedWidth, glassEnabled: glassEnabled)
        return CGSize(width: image.width, height: image.height)
    }

    private func renderedImage(of view: some View, proposedWidth: CGFloat, glassEnabled: Bool) throws -> CGImage
    {
        let suite = "ActionButtonLayoutTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(glassEnabled, forKey: PreferenceKey.enableLiquidGlassEffect)
        defaults.set(1.0, forKey: PreferenceKey.componentOpacity)
        defer { defaults.removePersistentDomain(forName: suite) }

        let renderer = ImageRenderer(content: view.defaultAppStorage(defaults))
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(width: proposedWidth, height: nil)
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

    private enum TestSource: String, QuerySourceOption
    {
        case academic
        var id: Self { self }
        var title: String { "本研教学一体化平台" }
    }
}
