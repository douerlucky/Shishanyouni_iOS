import SwiftUI
import UIKit
import Photos

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
