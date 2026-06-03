//
//  CurriculumExporter.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/3/16.
//

import SwiftUI

@MainActor
func exportCurriculumAsImage(
    courses: [Course],
    week: Int,
    datesCurWeek: [Int],
    month: Int,
    completion: @escaping () -> Void
) {
    let view = CurriculumExportView(
        courses: courses,
        week: week,
        datesCurWeek: datesCurWeek,
        month: month
    )

    let renderer = ImageRenderer(content: view)
    renderer.scale = 3.0

    guard let rendered = renderer.uiImage else {
        print("❌ 渲染失败")
        return
    }

    // 去掉 alpha 通道
    let format = UIGraphicsImageRendererFormat()
    format.opaque = true
    let opaqueImage = UIGraphicsImageRenderer(
        size: rendered.size, format: format
    ).image { ctx in
        UIColor.white.setFill()
        ctx.fill(CGRect(origin: .zero, size: rendered.size))
        rendered.draw(at: .zero)
    }

    UIImageWriteToSavedPhotosAlbum(opaqueImage, nil, nil, nil)
    print("✅ 课表已保存到相册")
    completion()   // 触发回调
}

// 专门用于导出的静态 View（不含底部按钮等 UI）
struct CurriculumExportView: View {
    let courses: [Course]
    let week: Int
    let datesCurWeek: [Int]
    let month: Int

    let weekDays = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("第 \(week) 周课表")
                    .font(.headline)
                Spacer()
                Text("\(month)月")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))

            // 日期头
            HStack(spacing: 0) {
                Color.clear.frame(width: 44)
                ForEach(0..<7, id: \.self) { i in
                    VStack(spacing: 2) {
                        Text(weekDays[i])
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("\(datesCurWeek[i])")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
            }
            .background(Color(.secondarySystemBackground))

            // 课程网格（复用现有组件）
            HStack(alignment: .top, spacing: 0) {
                TimeCurriculumView().frame(width: 44)
                CourseGridView(courses: courses, nowdisplayWeek: week)
            }
        }
        .background(Color(.systemGroupedBackground))
        .frame(width: 390)  // 固定宽度，适配 iPhone 主流尺寸
    }
}
