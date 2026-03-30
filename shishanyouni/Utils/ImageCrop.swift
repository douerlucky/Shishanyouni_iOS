//
//  ImageCrop.swift
//  shishanyouni
//
//  Rewritten — 2026/3/30
//

import SwiftUI

// MARK: - 裁剪视图

struct ImageCropperView: View {
    let normalizedImage: UIImage
    let onCrop: (UIImage) -> Void

    @Environment(\.dismiss) var dismiss

    /// 裁剪框目标比例：9:19.5（iPhone 竖屏标准）
    private let targetRatio: CGFloat = 9.0 / 19.5

    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    // 双指缩放相关的 State
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    /// 由 GeometryReader 在 onAppear 写入，供裁图函数使用
    @State private var screenSize: CGSize = .zero

    init(image: UIImage, onCrop: @escaping (UIImage) -> Void) {
        // 关键修复：消除相机照片的默认旋转元数据，防止裁剪后图像方向错乱
        self.normalizedImage = image.normalized()
        self.onCrop = onCrop
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // ── 1. 全屏裁剪手势区 ──────────────────────────────────────
            GeometryReader { geo in
                let sw = geo.size.width
                let sh = geo.size.height
                let cropW = sw - 40
                let cropH = cropW / targetRatio

                ZStack {
                    // 图片层
                    Image(uiImage: normalizedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: sw, height: sh)
                        .scaleEffect(scale) // 关键：在此处应用缩放
                        .offset(offset)     // 偏移量
                        .allowsHitTesting(false)

                    // 半透明遮罩（中间镂空）
                    Color.black.opacity(0.52)
                        .reverseMask {
                            RoundedRectangle(cornerRadius: 14)
                                .frame(width: cropW, height: cropH)
                        }
                        .allowsHitTesting(false)

                    // 裁剪框描边
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5)
                        .frame(width: cropW, height: cropH)
                        .allowsHitTesting(false)

                    // 三等分辅助线（帮助构图）
                    CropGridLines(width: cropW, height: cropH)
                        .allowsHitTesting(false)

                    // 手势捕获层
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { val in
                                    let proposed = CGSize(
                                        width:  lastOffset.width  + val.translation.width,
                                        height: lastOffset.height + val.translation.height
                                    )
                                    // 阻尼回弹计算
                                    offset = resistedOffset(
                                        proposed,
                                        screenW: sw, screenH: sh,
                                        cropW: cropW, cropH: cropH,
                                        currentScale: scale
                                    )
                                }
                                .onEnded { _ in
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                                        offset = clampedOffset(
                                            offset,
                                            screenW: sw, screenH: sh,
                                            cropW: cropW, cropH: cropH,
                                            currentScale: scale
                                        )
                                    }
                                    lastOffset = offset
                                }
                        )
                        .simultaneousGesture(
                            // 关键修复：加入缩放手势并允许与拖拽同时进行
                            MagnificationGesture()
                                .onChanged { val in
                                    scale = lastScale * val
                                }
                                .onEnded { _ in
                                    let minS = getMinScale(sw: sw, sh: sh, cropW: cropW, cropH: cropH)
                                    let maxS: CGFloat = 5.0
                                    
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                                        // 限制缩放比例
                                        if scale < minS { scale = minS }
                                        else if scale > maxS { scale = maxS }
                                        
                                        // 缩放结束后，需要重新校验偏移量，防止缩小后图像边缘脱离裁剪框
                                        offset = clampedOffset(
                                            offset,
                                            screenW: sw, screenH: sh,
                                            cropW: cropW, cropH: cropH,
                                            currentScale: scale
                                        )
                                    }
                                    lastScale = scale
                                    lastOffset = offset
                                }
                        )
                }
                .onAppear { screenSize = geo.size }
            }
            .ignoresSafeArea()
            
            // ── 2. 沉浸式顶部控制栏（彻底抛弃旧版 NavigationBar）───────────
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Text("取消")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.white)
                    }
                    .padding(8)
                    
                    Spacer()
                    
                    Button(action: {
                        cropAndDismiss()
                    }) {
                        Text("使用")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.black.opacity(0.6), Color.clear]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                Spacer()
                
                Text("双指缩放调整大小，单指拖动位置")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 60)
            }
        }
        .toolbar(.hidden, for: .navigationBar) // 隐藏系统导航栏
    }

    // MARK: - 执行裁剪

    private func cropAndDismiss() {
        let sw = screenSize.width
        let cropW = sw - 40
        let cropH = cropW / targetRatio
        if let cropped = cropImage(
            screenSize: screenSize,
            cropSize: CGSize(width: cropW, height: cropH)
        ) {
            onCrop(cropped)
        }
        dismiss()
    }

    // MARK: - 边界与缩放计算

    private func getFillScale(sw: CGFloat, sh: CGFloat) -> CGFloat {
        max(sw / normalizedImage.size.width, sh / normalizedImage.size.height)
    }

    /// 保证图片缩小到极限时，依然能盖住中间的裁剪框
    private func getMinScale(sw: CGFloat, sh: CGFloat, cropW: CGFloat, cropH: CGFloat) -> CGFloat {
        let fillScale = getFillScale(sw: sw, sh: sh)
        let baseW = normalizedImage.size.width * fillScale
        let baseH = normalizedImage.size.height * fillScale
        return max(cropW / baseW, cropH / baseH)
    }

    private func maxOffset(
        screenW: CGFloat, screenH: CGFloat,
        cropW: CGFloat, cropH: CGFloat,
        currentScale: CGFloat
    ) -> CGSize {
        let fillScale = getFillScale(sw: screenW, sh: screenH)
        let renderedW = normalizedImage.size.width  * fillScale * currentScale
        let renderedH = normalizedImage.size.height * fillScale * currentScale
        return CGSize(
            width:  max(0, (renderedW - cropW) / 2),
            height: max(0, (renderedH - cropH) / 2)
        )
    }

    private func clampedOffset(
        _ o: CGSize,
        screenW: CGFloat, screenH: CGFloat,
        cropW: CGFloat, cropH: CGFloat,
        currentScale: CGFloat
    ) -> CGSize {
        let lim = maxOffset(screenW: screenW, screenH: screenH, cropW: cropW, cropH: cropH, currentScale: currentScale)
        return CGSize(
            width:  min(lim.width,  max(-lim.width,  o.width)),
            height: min(lim.height, max(-lim.height, o.height))
        )
    }

    private func resistedOffset(
        _ o: CGSize,
        screenW: CGFloat, screenH: CGFloat,
        cropW: CGFloat, cropH: CGFloat,
        currentScale: CGFloat
    ) -> CGSize {
        let lim = maxOffset(screenW: screenW, screenH: screenH, cropW: cropW, cropH: cropH, currentScale: currentScale)
        func resist(_ v: CGFloat, limit: CGFloat) -> CGFloat {
            if v >  limit { return  limit + (v - limit) * 0.25 }
            if v < -limit { return -limit + (v + limit) * 0.25 }
            return v
        }
        return CGSize(
            width:  resist(o.width,  limit: lim.width),
            height: resist(o.height, limit: lim.height)
        )
    }

    // MARK: - 裁图核心算法

    private func cropImage(screenSize: CGSize, cropSize: CGSize) -> UIImage? {
        let imgSize = normalizedImage.size
        let sw = screenSize.width
        let sh = screenSize.height

        let fillScale = getFillScale(sw: sw, sh: sh)
        let renderedW = imgSize.width  * fillScale * scale
        let renderedH = imgSize.height * fillScale * scale

        // 图片左上角在屏幕坐标中的位置（含缩放与偏移）
        let imgLeft = (sw - renderedW) / 2 + offset.width
        let imgTop  = (sh - renderedH) / 2 + offset.height

        // 裁剪框左上角在屏幕坐标中的位置（居中）
        let cropLeft = (sw - cropSize.width)  / 2
        let cropTop  = (sh - cropSize.height) / 2

        // 换算为原始图片像素坐标
        let toPixel = imgSize.width / renderedW
        let s = normalizedImage.scale
        let rect = CGRect(
            x:      (cropLeft - imgLeft) * toPixel * s,
            y:      (cropTop  - imgTop)  * toPixel * s,
            width:  cropSize.width  * toPixel * s,
            height: cropSize.height * toPixel * s
        )

        guard let cgImg = normalizedImage.cgImage?.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cgImg, scale: s, orientation: .up) // 图像已被 normalized
    }
}

// MARK: - 三等分辅助线

private struct CropGridLines: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            ForEach(1..<3) { i in
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 0.5, height: height)
                    .offset(x: width / 3 * CGFloat(i) - width / 2)
            }
            ForEach(1..<3) { i in
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: width, height: 0.5)
                    .offset(y: height / 3 * CGFloat(i) - height / 2)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - 扩展方法

extension View {
    /// 正确挖洞遮罩
    @ViewBuilder
    func reverseMask<M: View>(
        alignment: Alignment = .center,
        @ViewBuilder _ mask: () -> M
    ) -> some View {
        self.mask(
            ZStack(alignment: alignment) {
                Rectangle()
                mask().blendMode(.destinationOut)
            }
            .compositingGroup()
        )
    }
}

extension UIImage {
    /// 标准化图像方向，消除元数据旋转（关键！防止裁剪结果横向错乱）
    func normalized() -> UIImage {
        if imageOrientation == .up { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
