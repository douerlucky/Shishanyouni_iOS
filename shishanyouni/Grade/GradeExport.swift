//
//  GradeExport.swift
//  shishanyouni
//

import SwiftUI
import UIKit
import Photos

/// 用于 ImageRenderer 的完整成绩内容。
///
/// 屏幕上的成绩页使用 ScrollView + LazyVGrid；导出时使用普通 VStack 和 HStack，
/// 让所有成绩卡片都参与布局，同时保持页面上的两列布局。
struct GradeExportView: View
{
    let grades: [Grade]

    var body: some View
    {
        VStack(alignment: .leading, spacing: 20)
        {
            Text("成绩查询")
                .font(.largeTitle.bold())
                .padding(.horizontal, 16)

            GradeSummaryCard(
                includedGrades: grades,
                allGrades: grades
            )

            Text("单科成绩")
                .font(.title2.bold())
                .padding(.horizontal, 16)

            // 使用普通 VStack + HStack，确保长图包含全部课程，并保持两列布局。
            VStack(spacing: 14)
            {
                ForEach(Array(stride(from: 0, to: grades.count, by: 2)), id: \.self)
                { index in
                    HStack(alignment: .top, spacing: 14)
                    {
                        GradeCard(
                            grade: grades[index],
                            included: .constant(true)
                        )
                        // 导出结果是静态图片，不需要响应卡片中的勾选按钮。
                        .allowsHitTesting(false)
                        .frame(maxWidth: .infinity, alignment: .top)

                        if index + 1 < grades.count
                        {
                            GradeCard(
                                grade: grades[index + 1],
                                included: .constant(true)
                            )
                            .allowsHitTesting(false)
                            .frame(maxWidth: .infinity, alignment: .top)
                        }
                        else
                        {
                            // 奇数门课程时保留右侧空位，避免最后一张卡片变成整行宽度。
                            Color.clear
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 20)
        .frame(width: UIScreen.main.bounds.width)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

private enum GradeExportError: LocalizedError
{
    case noGrades
    case renderFailed
    case photoAccessDenied
    case saveFailed(String)

    var errorDescription: String?
    {
        switch self
        {
        case .noGrades:
            return "请至少勾选一门成绩后再导出。"
        case .renderFailed:
            return "成绩长图生成失败，请稍后重试。"
        case .photoAccessDenied:
            return "没有相册写入权限，请在系统设置中允许访问照片。"
        case .saveFailed(let message):
            return message
        }
    }
}

/// 渲染成绩长图并保存到系统相册。
///
/// ImageRenderer 负责生成 UIImage，PhotoKit 负责确认保存是否成功。
@MainActor
func exportGrade(
    grades: [Grade],
    completion: @escaping (Result<Void, Error>) -> Void
)
{
    guard !grades.isEmpty else
    {
        completion(.failure(GradeExportError.noGrades))
        return
    }

    let exportView = GradeExportView(grades: grades)
    let renderer = ImageRenderer(content: exportView)
    renderer.scale = UIScreen.main.scale
    renderer.isOpaque = true

    guard let image = renderer.uiImage else
    {
        completion(.failure(GradeExportError.renderFailed))
        return
    }

    // 只写入相册，不读取用户已有照片，所以使用 addOnly 权限。
    PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
        guard status == .authorized || status == .limited else
        {
            DispatchQueue.main.async
            {
                completion(.failure(GradeExportError.photoAccessDenied))
            }
            return
        }

        PHPhotoLibrary.shared().performChanges
        {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
        completionHandler: { success, error in
            DispatchQueue.main.async
            {
                if success
                {
                    completion(.success(()))
                }
                else
                {
                    completion(.failure(
                        GradeExportError.saveFailed(
                            error?.localizedDescription ?? "保存到相册失败，请稍后重试。"
                        )
                    ))
                }
            }
        }
    }
}
