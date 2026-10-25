//
//  CurriculumSettingView.swift
//  shishanyouni
//
//  Originally by douer_lucky on 2026/2/11.
//  课表设置与保存；两种来源的导入流程独立放在 importCurriculum。
//

import SwiftUI
import PhotosUI
import UIKit

struct CurriculumSettingView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var userinfo: userInfo
    @EnvironmentObject private var iapStore: IAPStore

    @Binding var semesterStartDate: Date
    @Binding var courses: [Course]
    
    @AppStorage("scheduleBackgroundImageFilename") private var backgroundImageFilename: String = ""
    @AppStorage(PreferenceKey.curriculumBackgroundEnabled) private var curriculumBackgroundEnabled = true
    @AppStorage("scheduleBackgroundOpacity") private var backgroundOpacity: Double = 0.2
    @AppStorage("scheduleContentOpacity") private var scheduleContentOpacity: Double = 1.0
    @AppStorage(PreferenceKey.showNoonPeriod) private var showNoonPeriod = false
    @AppStorage(PreferenceKey.showEveningPeriod) private var showEveningPeriod = false

    /// `nil` 表示从未设置过开学日期，不能用任意默认日期伪装成已有数据。
    @State private var tempStartDate: Date?
    @State private var hasLoadedSemesterStartDate = false
    @State private var showSemesterStartDatePicker = false
    @State private var draftSemesterStartDate = Date()

    @State private var hasUserSelectedDate   = false
    @State private var showSaveConfirmation  = false
    @State private var hasPendingImportedSchedule = false
    @State private var showImportExitConfirmation = false
    @State private var showImportPicker      = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showSubscription = false

    // 三种清除方案
    @State private var showClearImportedConfirmation = false
    @State private var showClearManualConfirmation   = false
    @State private var showClearAllConfirmation      = false

    @State private var hasSelectedPhoto = false
    // 裁剪器：用 navigationDestination push 进去，不用 sheet
    @State private var showCropper: Bool = false
    @State private var photoToCrop: UIImage? = nil
    
    @AppStorage("enableLiquidGlassEffect") private var enableLiquidGlassEffect: Bool = false

    @AppStorage("scheduleNotificationMinutes") private var notificationMinutes: Int = 10
    @State private var pendingNotificationCount: Int = 0

    @AppStorage("semesterStartDateTimestamp") private var savedTimestamp: Double = 0

    var body: some View {
        NavigationStack {
            Form {
                dateSection
                importSection
                clearSection
                notificationSection
                periodSection
                saveSection
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: requestDismissal) { Image(systemName: "xmark") }
                }
            }
        }
        // 导入相关的 presenter 必须挂在稳定的页面根节点，而不是 Form/Section 内。
        // 否则 Form 刷新时会让正在显示的选择器被 SwiftUI 自动取消。
        .sheet(isPresented: $showImportPicker) {
            CurriculumImportView(courses: $courses) { importedStartDate in
                hasPendingImportedSchedule = true
                if let importedStartDate {
                    tempStartDate = importedStartDate
                    hasUserSelectedDate = true
                }
            }
        }
        .sheet(isPresented: $showSemesterStartDatePicker) {
            semesterStartDatePickerView
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
        .alert(
            "是否保存该课表？",
            isPresented: $showImportExitConfirmation,
            actions: {
                Button("保存课表") {
                    // 与页面底部的“保存设置”按钮共用同一条保存路径。
                    saveSettings()
                }
                .disabled(!canSaveSettings)

                Button("直接退出", role: .destructive) {
                    dismiss()
                }
            },
            message: {
                Text("已导入的课表尚未确认保存。")
            }
        )
        .fullScreenCover(isPresented: $showCropper) {
            if let photo = photoToCrop {
                ImageCropperView(image: photo) { cropped in
                    saveBackgroundImage(cropped)
                    hasSelectedPhoto = true
                }
            }
        }
        .onAppear(perform: loadSemesterStartDateIfNeeded)
    }

    // MARK: - 拆分后的 Section (解决编译器超时问题)

    private var dateSection: some View {
        Section {
            if tempStartDate == nil {
                Button {
                    draftSemesterStartDate = Calendar.current.startOfDay(for: Date())
                    showSemesterStartDatePicker = true
                } label: {
                    HStack {
                        Text("本学期开学日期")
                        Spacer()
                        Text("未设置")
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowSeparator(.hidden) // 消除分隔线
            } else {
                DatePicker(
                    "本学期开学日期",
                    selection: semesterStartDateBinding,
                    displayedComponents: [.date]
                )
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .listRowSeparator(.hidden) // 消除分隔线
            }
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
                        Text("导入课表")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
            }
            .disabled(userinfo.username.isEmpty)
            .listRowSeparator(.hidden) // 消除分隔线
        } header: {
            Text("课表导入")
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

    private var notificationSection: some View {
        Section {
            Picker("提前提醒", selection: $notificationMinutes) {
                Text("5分钟").tag(5)
                Text("10分钟").tag(10)
                Text("15分钟").tag(15)
            }
            .onChange(of: notificationMinutes) { newValue in
                CurriculumNotificationManager.shared.reminderMinutesBefore = newValue
                CurriculumNotificationManager.shared.rescheduleAllNotifications()
            }

            Button {
                CurriculumNotificationManager.shared.cancelAllClassReminders()
                pendingNotificationCount = 0
            } label: {
                HStack {
                    Spacer()
                    Text("清除所有上课提醒")
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                    Spacer()
                }
            }
            .listRowSeparator(.hidden)
        } header: {
            Text("上课提醒")
        } footer: {
            Text(pendingNotificationCount > 0
                 ? "当前已设置 \(pendingNotificationCount) 个上课提醒"
                 : "尚未设置上课提醒，请在「全部课程」中为课程开启提醒")
                .font(.caption)
        }
        .onAppear {
            CurriculumNotificationManager.shared.pendingNotificationCount { count in
                pendingNotificationCount = count
            }
        }
    }

    private var periodSection: some View {
        Section {
            premiumPeriodToggle(
                title: "显示中午时段",
                time: "11:40–14:30",
                isOn: $showNoonPeriod
            )

            premiumPeriodToggle(
                title: "显示晚上时段",
                time: "18:10–19:00",
                isOn: $showEveningPeriod
            )
        } header: {
            Text("时段设置")
        } footer: {
            Text("中午和晚上时段属于校园通行证功能。关闭后仅隐藏对应行，已安排的课程不会被删除。")
                .font(.caption)
        }
    }

    private func premiumPeriodToggle(
        title: String,
        time: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: premiumPeriodBinding(isOn)) {
            HStack(spacing: 10) {
                Image(systemName: iapStore.hasActiveSubscription ? "clock.badge.checkmark" : "lock.fill")
                    .foregroundStyle(iapStore.hasActiveSubscription ? .blue : .orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .tint(.blue)
        .listRowSeparator(.hidden)
    }

    /// 未开通时仍允许点击开关，以便直接进入购买页；运行时实际显示还会再次校验权益。
    private func premiumPeriodBinding(_ storage: Binding<Bool>) -> Binding<Bool> {
        Binding(
            get: { storage.wrappedValue && iapStore.hasActiveSubscription },
            set: { wantsToShow in
                guard wantsToShow else {
                    storage.wrappedValue = false
                    return
                }

                guard iapStore.hasActiveSubscription else {
                    showSubscription = true
                    return
                }

                storage.wrappedValue = true
            }
        )
    }

    private var backgroundSection: some View {
        Section {
            NavigationLink(destination: BackgroundSettingView()) {
                HStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title3)
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("背景图片设置")
                            .font(.body)
                        Text("背景图 · 透明度 · 液态玻璃")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("课表外观")
        }
    }

    private var saveSection: some View {
        Section {
            Button {
                saveSettings()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                    Text("保存设置")
                        .font(.headline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                // 纯蓝色主操作，玻璃效果统一复用全局的 optionalLiquidGlass。
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(canSaveSettings ? Color.blue : Color.blue.opacity(0.35))
                }
                .optionalLiquidGlass(enabled: enableLiquidGlassEffect, allowsNesting: true, cornerRadius: 18)
                .shadow(color: .blue.opacity(canSaveSettings ? 0.28 : 0), radius: 12, y: 6)
            }
            .buttonStyle(LiquidGlassPrimaryButtonStyle(isEnabled: canSaveSettings))
            .disabled(!canSaveSettings)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
        }
        .alert("设置已保存", isPresented: $showSaveConfirmation) {
            Button("确定", role: .cancel) { dismiss() }
        } message: {
            if let tempStartDate {
                Text("开学日期已更新为 \(formatDate(tempStartDate))")
            } else {
                Text("设置已保存")
            }
        }
    }

    // MARK: - Import Picker

    private var semesterStartDatePickerView: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "本学期开学日期",
                    selection: $draftSemesterStartDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .padding()

                Spacer()
            }
            .navigationTitle("设置开学日期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { showSemesterStartDatePicker = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确定") {
                        updateSemesterStartDate(draftSemesterStartDate)
                        showSemesterStartDatePicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }
    
    private func persistCourses(_ courses: [Course]) {
        CurriculumStore.shared.saveCourses(courses, semesterStart: nil)
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
        CurriculumWidgetSync.clearCourses()
        NextCourseSync.clear()
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
        guard canSaveSettings else { return }
        if let tempStartDate {
            semesterStartDate = tempStartDate
            savedTimestamp = tempStartDate.timeIntervalSince1970
            CurriculumStore.shared.saveSemesterStartTimestamp(savedTimestamp)
        }
        CurriculumWidgetSync.saveBackgroundMetadata(filename: backgroundImageFilename, opacity: backgroundOpacity)
        hasPendingImportedSchedule = false
        showSaveConfirmation = true
    }

    /// 只有导入后的课表还未走过原有保存流程时，关闭才需要二次确认。
    private func requestDismissal() {
        if hasPendingImportedSchedule {
            showImportExitConfirmation = true
        } else {
            dismiss()
        }
    }

    private var canSaveSettings: Bool {
        hasUserSelectedDate || hasSelectedPhoto || (hasPendingImportedSchedule && tempStartDate != nil)
    }

    private var semesterStartDateBinding: Binding<Date> {
        Binding(
            get: { tempStartDate ?? Calendar.current.startOfDay(for: Date()) },
            set: updateSemesterStartDate
        )
    }

    private func updateSemesterStartDate(_ date: Date) {
        hasUserSelectedDate = true
        tempStartDate = date
        adjustToMonday(date)
    }

    private func loadSemesterStartDateIfNeeded() {
        guard !hasLoadedSemesterStartDate else { return }
        hasLoadedSemesterStartDate = true

        if savedTimestamp > 0 {
            tempStartDate = Date(timeIntervalSince1970: savedTimestamp)
        } else if let sharedDate = CurriculumStore.shared.loadSemesterStartDate() {
            tempStartDate = sharedDate
            savedTimestamp = sharedDate.timeIntervalSince1970
        }
    }

    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale     = Locale(identifier: "zh_CN")
        fmt.dateFormat = "yyyy年MM月dd日 (EEEE)"
        return fmt.string(from: date)
    }
    
    private func saveBackgroundImage(_ image: UIImage) {
        do {
            let filename = try BackgroundImageStore.saveImage(
                image,
                replacing: backgroundImageFilename
            )
            backgroundImageFilename = filename
            curriculumBackgroundEnabled = true
            CurriculumWidgetSync.saveBackgroundMetadata(filename: filename, opacity: backgroundOpacity)
        } catch {
            print("Failed to save background image: \(error)")
        }
    }
    
    private func clearBackgroundImage() {
        BackgroundImageStore.removeImage(named: backgroundImageFilename)
        backgroundImageFilename = ""
        CurriculumWidgetSync.clearBackgroundMetadata()
    }
}

/// 让自定义主按钮保留系统按钮应有的按压反馈，而不退回 Form 的普通文字按钮外观。
private struct LiquidGlassPrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && isEnabled ? 0.97 : 1)
            .brightness(configuration.isPressed && isEnabled ? -0.06 : 0)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
            .opacity(isEnabled ? 1 : 0.58)
    }
}

// MARK: - Preview

#Preview {
    CurriculumSettingView(
        semesterStartDate: .constant(Date()),
        courses: .constant([])
    )
    .environmentObject(userInfo())
    .environmentObject(IAPStore.preview(hasActiveSubscription: true))
}
