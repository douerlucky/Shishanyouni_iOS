//
//  BackgroundImageStore.swift
//  shishanyouni
//

import Foundation
import UIKit

/// App 内自定义背景图的唯一存储入口。
///
/// 主 App 使用 Documents 目录持久化图片；Widget 使用 App Group 容器读取同一文件名。
/// 任何页面都只应通过这里加载、保存或删除，避免不同页面出现不同的回退策略。
enum BackgroundImageStore
{
    private static let filenamePrefix = "schedule_background_"
    private static let jpegCompressionQuality: CGFloat = 0.8

    /// 按顺序从主 App 的 Documents 和 App Group 读取图片。
    ///
    /// App Group 回退兼容早期只成功写入共享容器，或从旧版本迁移而来的背景图。
    static func loadImage(named filename: String) -> UIImage?
    {
        guard !filename.isEmpty else { return nil }

        for url in candidateURLs(for: filename)
        {
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data)
            {
                return image
            }
        }

        return nil
    }

    /// 保存一张背景图，并同时写入 Widget 需要的 App Group 副本。
    ///
    /// 主 App 的本地副本是唯一必需项；共享副本写入失败时不影响用户设置背景，
    /// 但 Widget 会自然回退到自己的默认外观。
    static func saveImage(_ image: UIImage, replacing previousFilename: String?) throws -> String
    {
        guard let data = image.jpegData(compressionQuality: jpegCompressionQuality) else
        {
            throw BackgroundImageStoreError.cannotEncodeImage
        }

        let filename = "\(filenamePrefix)\(UUID().uuidString).jpg"
        try data.write(to: documentsURL.appendingPathComponent(filename), options: .atomic)

        if let sharedURL = appGroupURL(for: filename)
        {
            try? data.write(to: sharedURL, options: .atomic)
        }

        if let previousFilename, previousFilename != filename
        {
            removeImage(named: previousFilename)
        }

        return filename
    }

    /// 同时删除主 App 与 App Group 中的副本；缺少任一副本都视为正常情况。
    static func removeImage(named filename: String)
    {
        guard !filename.isEmpty else { return }

        for url in candidateURLs(for: filename)
        {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static var documentsURL: URL
    {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private static func appGroupURL(for filename: String) -> URL?
    {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: WidgetAppGroup.identifier)?
            .appendingPathComponent(filename)
    }

    private static func candidateURLs(for filename: String) -> [URL]
    {
        let localURL = documentsURL.appendingPathComponent(filename)
        if let sharedURL = appGroupURL(for: filename), sharedURL != localURL
        {
            return [localURL, sharedURL]
        }
        return [localURL]
    }
}

enum BackgroundImageStoreError: LocalizedError
{
    case cannotEncodeImage

    var errorDescription: String?
    {
        switch self
        {
        case .cannotEncodeImage:
            return "无法将图片转换为可保存的 JPEG 数据。"
        }
    }
}
