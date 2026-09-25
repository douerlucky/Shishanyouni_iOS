//
//  BackgroundSettingView.swift
//  shishanyouni
//
//  统一样式背景设置页面：控制课表、首页、日程的背景/透明度/液态玻璃
//

import SwiftUI
import PhotosUI

/// 每个页面的背景独立配置
struct PageBackgroundConfig
{
    let key: String
    let label: String
    let icon: String
}

private let pageConfigs: [PageBackgroundConfig] = [
    PageBackgroundConfig(key: "curriculumBackgroundEnabled", label: "课表", icon: "calendar"),
    PageBackgroundConfig(key: "homeBackgroundEnabled", label: "首页", icon: "house.fill"),
    PageBackgroundConfig(key: "scheduleBackgroundEnabled", label: "日程", icon: "calendar.badge.clock"),
]

struct BackgroundSettingView: View
{
    // 共享参数
    @AppStorage("scheduleBackgroundImageFilename") private var backgroundImageFilename: String = ""
    @AppStorage("scheduleBackgroundOpacity") private var backgroundOpacity: Double = 0.2
    @AppStorage("scheduleContentOpacity") private var scheduleContentOpacity: Double = 1.0
    @AppStorage("enableLiquidGlassEffect") private var enableLiquidGlassEffect: Bool = false

    // 各页面单独开关
    @AppStorage("curriculumBackgroundEnabled") private var curriculumEnabled = true
    @AppStorage("homeBackgroundEnabled") private var homeEnabled = false
    @AppStorage("scheduleBackgroundEnabled") private var scheduleEnabled = false

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showCropper = false
    @State private var photoToCrop: UIImage?
    @State private var previewImage: UIImage?

    var body: some View
    {
        List
        {
            // 选择图片
            Section
            {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images)
                {
                    Label("选择背景图片", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .fontWeight(.semibold)
                }
                .onChange(of: selectedPhotoItem) { newItem in
                    guard let item = newItem else { return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data)
                        {
                            await MainActor.run { self.photoToCrop = image }
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            await MainActor.run {
                                self.showCropper = true
                                self.selectedPhotoItem = nil
                            }
                        }
                    }
                }
            }

            // 预览
            if let preview = previewImage
            {
                Section
                {
                    VStack(spacing: 8)
                    {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.separator).opacity(0.3), lineWidth: 1)
                            )

                        Text("当前背景预览")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section
                {
                    Button(role: .destructive) {
                        clearBackgroundImage()
                        previewImage = nil
                    } label: {
                        Text("清除背景图片")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                }
            }

            // 启用页面选择
            Section
            {
                ForEach(pageConfigs, id: \.key) { config in
                    Toggle(isOn: binding(for: config.key))
                    {
                        HStack(spacing: 12)
                        {
                            Image(systemName: config.icon)
                                .foregroundColor(.accentColor)
                                .frame(width: 20)

                            Text(config.label)
                                .foregroundColor(.primary)

                            Spacer()
                        }
                    }
                }
            } header: {
                Text("页面背景配置")
            } footer: {
         
            }

            // 透明度与效果
            Section
            {
                VStack(alignment: .leading) {
                    Text("背景不透明度: \(Int(backgroundOpacity * 100))%")
                        .font(.subheadline)
                    Slider(value: $backgroundOpacity, in: 0.0...1.0, step: 0.05)
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading) {
                    Text("内容不透明度: \(Int(scheduleContentOpacity * 100))%")
                        .font(.subheadline)
                    Slider(value: $scheduleContentOpacity, in: 0.0...1.0, step: 0.05)
                }
                .padding(.vertical, 4)

                if #available(iOS 26.0, *)
                {
                    Toggle("背景液态玻璃效果", isOn: $enableLiquidGlassEffect)
                }
            }
        }
        .navigationTitle("背景设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .listStyle(.insetGrouped)
        .fullScreenCover(isPresented: $showCropper)
        {
            if let photo = photoToCrop
            {
                ImageCropperView(image: photo) { cropped in
                    saveBackgroundImage(cropped)
                    previewImage = cropped
                }
            }
        }
        .onAppear { loadPreviewImage() }
    }

    private func binding(for key: String) -> Binding<Bool>
    {
        switch key
        {
        case "curriculumBackgroundEnabled": return $curriculumEnabled
        case "homeBackgroundEnabled": return $homeEnabled
        case "scheduleBackgroundEnabled": return $scheduleEnabled
        default: return .constant(false)
        }
    }

    private func loadPreviewImage()
    {
        previewImage = BackgroundImageStore.loadImage(named: backgroundImageFilename)
    }

    private func saveBackgroundImage(_ image: UIImage)
    {
        do
        {
            let filename = try BackgroundImageStore.saveImage(
                image,
                replacing: backgroundImageFilename
            )
            backgroundImageFilename = filename
            // 选择图片就是明确要使用它；默认先应用到课表，其他页面仍由用户单独开关。
            curriculumEnabled = true
            CurriculumWidgetSync.saveBackgroundMetadata(filename: filename, opacity: backgroundOpacity)
        }
        catch { print("Failed to save background image: \(error)") }
    }

    private func clearBackgroundImage()
    {
        BackgroundImageStore.removeImage(named: backgroundImageFilename)
        backgroundImageFilename = ""
        CurriculumWidgetSync.clearBackgroundMetadata()
    }
}

#Preview {
    NavigationStack { BackgroundSettingView() }
}
