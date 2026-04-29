//
//  ScheduleSettingView.swift
//  shishanyouni
//
//  Originally by douer_lucky on 2026/2/11.
//  Refactored: uses new ScheduleService (lion.hzau.edu.cn iOS API).
//

import SwiftUI
import PhotosUI
import UIKit

struct ScheduleSettingView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var userinfo: userInfo

    @Binding var semesterStartDate: Date
    @Binding var courses: [Course]
    
    @AppStorage("scheduleBackgroundImageFilename") private var backgroundImageFilename: String = ""
    @AppStorage("scheduleBackgroundOpacity") private var backgroundOpacity: Double = 0.2
    @AppStorage("scheduleContentOpacity") private var scheduleContentOpacity: Double = 1.0

    @State private var tempStartDate: Date = {
        let components = DateComponents(year: 2026, month: 3, day: 2)
        return Calendar.current.date(from: components) ?? Date()
    }()

    @State private var hasUserSelectedDate   = false
    @State private var showSaveConfirmation  = false
    @State private var showImportPicker      = false
    @State private var showImportAlert       = false
    @State private var showClearConfirmation = false
    @State private var importAlertMessage    = ""
    @State private var isImporting           = false
    @State private var importedCount         = 0
    @State private var selectedPhotoItem: PhotosPickerItem?

    // 导入时询问是否同时清除手动课程
    @State private var pendingImportResult: (courses: [Course], startDate: Date?)? = nil
    @State private var showClearManualOnImportAlert = false

    // 三种清除方案
    @State private var showClearImportedConfirmation = false
    @State private var showClearManualConfirmation   = false
    @State private var showClearAllConfirmation      = false

    // 导入学期选择
    @State private var selectedYear     = "2025"       // 学年起始年份
    @State private var selectedTerm     = "2"          // "1"=秋季, "2"=春季
    
    @State private var hasSelectedPhoto = false
    // 裁剪器：用 navigationDestination push 进去，不用 sheet
    @State private var showCropper: Bool = false
    @State private var photoToCrop: UIImage? = nil
    
    @AppStorage("enableLiquidGlassEffect") private var enableLiquidGlassEffect: Bool = false

    @AppStorage("semesterStartDateTimestamp") private var savedTimestamp: Double = 0

    /// 学年显示列表
    private let availableYears  = ["2023", "2024", "2025", "2026"]
    private let terms           = [("秋季学期", "1"), ("春季学期", "2")]

    var body: some View {
        NavigationStack {
            Form {
                dateSection
                importSection
                clearSection
                backgroundSection
                saveSection
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }        .fullScreenCover(isPresented: $showCropper) {
                if let photo = photoToCrop {
                    ImageCropperView(image: photo) { cropped in
                        saveBackgroundImage(cropped)
                        hasSelectedPhoto = true
                    }
                }
            }
        }
    }

    // MARK: - 拆分后的 Section (解决编译器超时问题)

    private var dateSection: some View {
        Section {
            DatePicker(
                "本学期开学日期",
                selection: $tempStartDate,
                displayedComponents: [.date]
            )
            .environment(\.locale, Locale(identifier: "zh_CN"))
            .onChange(of: tempStartDate) { newValue in
                hasUserSelectedDate = true
                adjustToMonday(newValue)
            }
            .listRowSeparator(.hidden) // 消除分隔线
        } header: {
            Text("学期设置")
        }
    }

    private var importSection: some View {
        Section {
            Button {
                showImportPicker = true
            } label: {
                if userinfo.username.isEmpty {
                    Text("请先在个人页面登录")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                } else {
                    HStack {
                        Spacer()
                        if isImporting { ProgressView().padding(.trailing, 8) }
                        Text(isImporting ? "导入中…" : "导入课表")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
            }
            .disabled(userinfo.username.isEmpty || isImporting)
            .listRowSeparator(.hidden) // 消除分隔线
        } header: {
            Text("课表导入")
        }
        // 把弹窗绑在对应的 Section 上，分解编译器的压力！
        .sheet(isPresented: $showImportPicker) { importPickerView }
        .alert(importAlertMessage, isPresented: $showImportAlert) {
            Button("确定", role: .cancel) {}
        }
        .alert("是否同时清除手动添加的课程？", isPresented: $showClearManualOnImportAlert) {
            Button("清除", role: .destructive) {
                if let result = pendingImportResult {
                    applyImport(result, keepManual: false)
                }
            }
            Button("保留") {
                if let result = pendingImportResult {
                    applyImport(result, keepManual: true)
                }
            }
            Button("取消", role: .cancel) {
                pendingImportResult = nil
                isImporting = false
            }
        } message: {
            Text("点击「保留」将保留手动课程，仅替换导入课程；点击「清除」将删除所有课程后重新导入。")
        }
    }

    private var clearSection: some View {
        Section {
            Button(role: .destructive) {
                showClearImportedConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text("清除导入的课程").fontWeight(.semibold)
                    Spacer()
                }
            }
            .disabled(courses.filter { !$0.isManual }.isEmpty)
            .listRowSeparator(.hidden)

            Button(role: .destructive) {
                showClearManualConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text("清除手动添加的课程").fontWeight(.semibold)
                    Spacer()
                }
            }
            .disabled(courses.filter { $0.isManual }.isEmpty)
            .listRowSeparator(.hidden)

            Button(role: .destructive) {
                showClearAllConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text("清除所有课程").fontWeight(.semibold)
                    Spacer()
                }
            }
            .disabled(courses.isEmpty)
            .listRowSeparator(.hidden)

        } header: {
            Text("清除课程")
        } footer: {
            let importedCount = courses.filter { !$0.isManual }.count
            let manualCount   = courses.filter {  $0.isManual }.count
            Text("导入课程 \(importedCount) 门 · 手动课程 \(manualCount) 门").font(.caption)
        }
        .alert("确认清除导入的课程", isPresented: $showClearImportedConfirmation) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) { clearImportedCourses() }
        } message: {
            Text("将删除所有自动导入的课程，手动添加的课程不受影响。")
        }
        .alert("确认清除手动添加的课程", isPresented: $showClearManualConfirmation) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) { clearManualCourses() }
        } message: {
            Text("将删除所有手动添加的课程，导入课程不受影响。")
        }
        .alert("确认清除所有课程", isPresented: $showClearAllConfirmation) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) { clearAllCourses() }
        } message: {
            Text("此操作将删除全部课程，包括导入和手动添加的，无法恢复。")
        }
    }

    private var backgroundSection: some View {
        Section {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack {
                    Spacer()
                    Text("选择背景图片").fontWeight(.semibold)
                    Spacer()
                }
            }
            .onChange(of: selectedPhotoItem) { newItem in
                // 增加守卫，防止我们下面置空时触发死循环
                guard let item = newItem else { return }
                
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        
                        await MainActor.run {
                            self.photoToCrop = image
                        }
                        
                        // 关键修复 1：让代码“睡” 0.5 秒，等待 PhotosPicker 完全降下去
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        
                        await MainActor.run {
                            self.showCropper = true
                            // 关键修复 2：用完之后把选中项置空。
                            // 这样如果你裁剪取消了，再选同一张图，onChange 才会再次触发！
                            self.selectedPhotoItem = nil
                        }
                    }
                }
            }
            .listRowSeparator(.hidden)
            
            if !backgroundImageFilename.isEmpty {
                Button(role: .destructive) {
                    clearBackgroundImage()
                    hasSelectedPhoto = true
                } label: {
                    HStack {
                        Spacer()
                        Text("清除背景图片").fontWeight(.semibold)
                        Spacer()
                    }
                }
                .listRowSeparator(.hidden)
            }
            
            VStack(alignment: .leading) {
                Text("背景不透明度: \(Int(backgroundOpacity * 100))%")
                    .font(.subheadline)
                Slider(value: $backgroundOpacity, in: 0.0...1.0, step: 0.05)
            }
            .padding(.vertical, 8)
            .listRowSeparator(.hidden)
            
            VStack(alignment: .leading) {
                Text("课表内容不透明度: \(Int(scheduleContentOpacity * 100))%")
                    .font(.subheadline)
                Slider(value: $scheduleContentOpacity, in: 0.0...1.0, step: 0.05)
            }
            .padding(.vertical, 8)
            .listRowSeparator(.hidden)
            if #available(iOS 26.0, *)
            {
                Toggle("背景液态玻璃效果", isOn: $enableLiquidGlassEffect)
            }
            
        } header: {
                Text("背景图片")
            
        }

    }

    private var saveSection: some View {
        Section {
            Button {
                saveSettings()
            } label: {
                HStack {
                    Spacer()
                    Text("保存设置").fontWeight(.semibold)
                    Spacer()
                }
            }
            .disabled(!hasUserSelectedDate && !hasSelectedPhoto)
            .listRowSeparator(.hidden)
        }
        .alert("设置已保存", isPresented: $showSaveConfirmation) {
            Button("确定", role: .cancel) { dismiss() }
        } message: {
            Text("开学日期已更新为 \(formatDate(tempStartDate))")
        }
    }

    // MARK: - Import Picker
    
    private var importPickerView: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("选择导入学期")
                    .font(.headline)
                    .padding(.top, 20)

                HStack(spacing: 20) {
                    // 学年选择（显示 "2025-2026" 形式，实际传 "2025"）
                    Picker("学年", selection: $selectedYear) {
                        ForEach(availableYears, id: \.self) { year in
                            Text("\(year)-\(String((Int(year) ?? 2025) + 1))")
                                .tag(year)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)

                    // 学期选择
                    Picker("学期", selection: $selectedTerm) {
                        ForEach(terms, id: \.1) { label, value in
                            Text(label).tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("导入课表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { showImportPicker = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确认") {
                        showImportPicker = false
                        Task { await importCourses() }
                    }
                    .disabled(isImporting)
                }
            }
        }
    }

    // MARK: 导入课表
    private func importCourses() async {
        isImporting = true

        guard !userinfo.username.isEmpty else {
            importAlertMessage = "课表导入失败\n请先登录"
            showImportAlert = true
            isImporting = false
            return
        }

        let plainPassword = userinfo.plainPassword

        guard !plainPassword.isEmpty else {
            importAlertMessage = "课表导入失败\n未找到密码，请重新登录"
            showImportAlert = true
            isImporting = false
            return
        }

        do {
            let result = try await ScheduleService.fetchCourses(
                username: userinfo.username,
                password: userinfo.encryptedPasswordShishanyouni,
                year:     selectedYear,
                term:     selectedTerm
            )

            importedCount = result.courses.count

            // 若存在手动课程，先询问是否清除
            let hasManual = courses.contains { $0.isManual }
            if hasManual {
                pendingImportResult = result
                showClearManualOnImportAlert = true
                // isImporting 等弹窗回调里再置 false
            } else {
                applyImport(result, keepManual: false)
            }

        } catch {
            print("❌ 导入失败: \(error)")
            importAlertMessage = "课表导入失败\n\(error.localizedDescription)"
            showImportAlert    = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            isImporting = false
        }
    }

    // MARK: - 持久化

    private func persistCourses(_ courses: [Course]) {
        WidgetSharedStore.saveCourses(courses)
        print("✅ 课表已保存到共享存储，共 \(courses.count) 条")
    }

    /// 将拉取结果写入 courses，keepManual 决定是否保留手动课程
    private func applyImport(_ result: (courses: [Course], startDate: Date?), keepManual: Bool) {
        let manual = keepManual ? courses.filter { $0.isManual } : []
        courses = manual + result.courses
        persistCourses(courses)

        if let apiDate = result.startDate {
            tempStartDate       = apiDate
            hasUserSelectedDate = true
            importAlertMessage  = "课表导入成功\n已获取 \(result.courses.count) 条排课\n开学日期已自动填写为 \(formatDate(apiDate))，请确认后保存"
        } else {
            importAlertMessage  = "课表导入成功\n已获取 \(result.courses.count) 条排课\n请手动设置开学日期后保存"
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showImportAlert = true
        pendingImportResult = nil
        isImporting = false
    }

    private func clearImportedCourses() {
        courses = courses.filter { $0.isManual }
        persistCourses(courses)
        print("✅ 已清除导入课程，保留手动课程 \(courses.count) 门")
    }

    private func clearManualCourses() {
        courses = courses.filter { !$0.isManual }
        persistCourses(courses)
        print("✅ 已清除手动课程，保留导入课程 \(courses.count) 门")
    }

    private func clearAllCourses() {
        courses = []
        WidgetSharedStore.clearCourses()
        print("✅ 所有课程已清空")
    }

    // MARK: - 工具函数

    /// 将所选日期调整为该周的周一
    private func adjustToMonday(_ date: Date) {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let weekday = cal.component(.weekday, from: date)
        let offset  = weekday == 1 ? -6 : -(weekday - 2)
        if offset != 0, let monday = cal.date(byAdding: .day, value: offset, to: date) {
            tempStartDate = monday
        }
    }

    private func saveSettings() {
        semesterStartDate   = tempStartDate
        savedTimestamp      = tempStartDate.timeIntervalSince1970
        WidgetSharedStore.saveSemesterStartTimestamp(savedTimestamp)
        WidgetSharedStore.saveBackgroundMeta(filename: backgroundImageFilename, opacity: backgroundOpacity)
        showSaveConfirmation = true
    }

    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale     = Locale(identifier: "zh_CN")
        fmt.dateFormat = "yyyy年MM月dd日 (EEEE)"
        return fmt.string(from: date)
    }
    
    private func saveBackgroundImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let filename = "schedule_background_\(UUID().uuidString).jpg"
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        do {
            try data.write(to: fileURL)
            // 删除旧文件
            if !backgroundImageFilename.isEmpty {
                let oldURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent(backgroundImageFilename)
                try? FileManager.default.removeItem(at: oldURL)
            }
            backgroundImageFilename = filename

            // 同步保存到 App Group 容器，供 Widget 读取
            if let sharedDir = WidgetSharedStore.sharedContainerURL() {
                let sharedURL = sharedDir.appendingPathComponent(filename)
                try? data.write(to: sharedURL)
            }
            WidgetSharedStore.saveBackgroundMeta(filename: filename, opacity: backgroundOpacity)
        } catch {
            print("Failed to save background image: \(error)")
        }
    }
    
    private func clearBackgroundImage() {
        if !backgroundImageFilename.isEmpty {
            let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(backgroundImageFilename)
            try? FileManager.default.removeItem(at: fileURL)

            if let sharedDir = WidgetSharedStore.sharedContainerURL() {
                let sharedURL = sharedDir.appendingPathComponent(backgroundImageFilename)
                try? FileManager.default.removeItem(at: sharedURL)
            }
            backgroundImageFilename = ""
            WidgetSharedStore.clearBackgroundMeta()
        }
    }
}

// MARK: - Preview

#Preview {
    ScheduleSettingView(
        semesterStartDate: .constant(Date()),
        courses: .constant([])
    )
    .environmentObject(userInfo())
}
