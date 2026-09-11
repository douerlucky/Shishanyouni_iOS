//
//  CurriculumSettingView.swift
//  shishanyouni
//
//  Originally by douer_lucky on 2026/2/11.
//  Refactored: uses new CurriculumService (lion.hzau.edu.cn iOS API).
//

import SwiftUI
import PhotosUI
import UIKit

struct CurriculumSettingView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var userinfo: userInfo

    @Binding var semesterStartDate: Date
    @Binding var courses: [Course]
    
    @AppStorage("scheduleBackgroundImageFilename") private var backgroundImageFilename: String = ""
    @AppStorage("scheduleBackgroundOpacity") private var backgroundOpacity: Double = 0.2
    @AppStorage("scheduleContentOpacity") private var scheduleContentOpacity: Double = 1.0

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
    /// 确认后等选择器完全收起再发请求，避免两个 sheet 在转场期间互相抢 presenter。
    @State private var shouldStartImportAfterPickerDismissal = false
    @State private var showImportAlert       = false
    @State private var showClearConfirmation = false
    @State private var importAlertMessage    = ""
    @State private var isImporting           = false
    @State private var importedCount         = 0
    @State private var importErrorRetryAction: (() -> Void)?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showMFASheet = false
    @State private var mfaMaskedPhone = ""
    @State private var mfaCode = ""
    @State private var mfaSendCodeAction: (() async -> String?)?
    @State private var mfaContinuation: CheckedContinuation<String?, Never>?

    // 导入时询问是否同时清除手动课程
    @State private var pendingImportResult: (courses: [Course], startDate: Date?)? = nil
    @State private var showClearManualOnImportAlert = false

    // 三种清除方案
    @State private var showClearImportedConfirmation = false
    @State private var showClearManualConfirmation   = false
    @State private var showClearAllConfirmation      = false

    // 导入学期选择
    @State private var selectedYear     = CurriculumSettingView.defaultImportSemester(for: Date()).year
    @State private var selectedTerm     = CurriculumSettingView.defaultImportSemester(for: Date()).term
    
    @State private var hasSelectedPhoto = false
    // 裁剪器：用 navigationDestination push 进去，不用 sheet
    @State private var showCropper: Bool = false
    @State private var photoToCrop: UIImage? = nil
    
    @AppStorage("enableLiquidGlassEffect") private var enableLiquidGlassEffect: Bool = false

    @AppStorage("scheduleNotificationMinutes") private var notificationMinutes: Int = 10
    @State private var pendingNotificationCount: Int = 0

    @AppStorage("semesterStartDateTimestamp") private var savedTimestamp: Double = 0

    /// 以当前学年为基准显示历史和后续可导入的学年，不再写死到 2026。
    private var availableYears: [String] {
        let currentAcademicYear = Int(Self.defaultImportSemester(for: Date()).year) ?? 2026
        return ((currentAcademicYear - 3)...(currentAcademicYear + 2)).map(String.init)
    }

    private let terms           = [("秋季学期", "1"), ("春季学期", "2")]

    var body: some View {
        NavigationStack {
            Form {
                dateSection
                importSection
                clearSection
                notificationSection
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
        .sheet(isPresented: $showImportPicker, onDismiss: importPickerDidDismiss) {
            importPickerView
        }
        .sheet(isPresented: $showSemesterStartDatePicker) {
            semesterStartDatePickerView
        }
        .sheet(isPresented: $showMFASheet) {
            mfaCodeInputSheet
        }
        .alert(importAlertMessage, isPresented: $showImportAlert) {
            if let retry = importErrorRetryAction {
                Button("重试", action: retry)
            }
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
                presentImportPicker()
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
                .optionalLiquidGlass(enabled: enableLiquidGlassEffect, cornerRadius: 18)
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
                    Button("取消") {
                        shouldStartImportAfterPickerDismissal = false
                        showImportPicker = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确认") {
                        // 在选择器收起的转场期间锁住入口，保证此次请求使用用户刚确认的学期。
                        isImporting = true
                        shouldStartImportAfterPickerDismissal = true
                        showImportPicker = false
                    }
                    .disabled(isImporting)
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private var mfaCodeInputSheet: some View {
        MFACodeInputSheet(
            maskedPhone: mfaMaskedPhone,
            code: $mfaCode,
            fromShishanyouni: true,
            onSendCode: $mfaSendCodeAction,
            onCancel: { resolveMFACode(nil) },
            onConfirm: { resolveMFACode(mfaCode.trimmingCharacters(in: .whitespacesAndNewlines)) }
        )
    }

    // MARK: 导入课表
    private func presentImportPicker() {
        let defaultSemester = Self.defaultImportSemester(for: Date())
        selectedYear = defaultSemester.year
        selectedTerm = defaultSemester.term
        shouldStartImportAfterPickerDismissal = false
        showImportPicker = true
    }

    private func importPickerDidDismiss() {
        guard shouldStartImportAfterPickerDismissal else { return }

        shouldStartImportAfterPickerDismissal = false
        Task { await importCourses() }
    }

    private func importCourses() async {
        isImporting = true
        importErrorRetryAction = nil

        guard !userinfo.username.isEmpty else {
            importAlertMessage = "课表导入失败\n请先登录"
            importErrorRetryAction = { Task { await self.importCourses() } }
            showImportAlert = true
            isImporting = false
            return
        }

        let plainPassword = userinfo.plainPassword

        guard !plainPassword.isEmpty else {
            importAlertMessage = "课表导入失败\n未找到密码，请重新登录"
            importErrorRetryAction = { Task { await self.importCourses() } }
            showImportAlert = true
            isImporting = false
            return
        }

        do {
            let result = try await fetchCoursesWithMFA()

            // 狮山课表接口负责课程主数据，考核方式由教务课表接口补充。
            // 补充链路失败时仍保留原有导入结果，避免辅助字段影响课表主流程。
            let enrichedCourses = await attachAssessmentMethods(to: result.courses)
            let enrichedResult = (courses: enrichedCourses, startDate: result.startDate)

            importedCount = enrichedResult.courses.count

            // 若存在手动课程，先询问是否清除
            let hasManual = courses.contains { $0.isManual }
            if hasManual {
                pendingImportResult = enrichedResult
                showClearManualOnImportAlert = true
                // isImporting 等弹窗回调里再置 false
            } else {
                applyImport(enrichedResult, keepManual: false)
            }

        } catch {
            print("❌ 导入失败: \(error)")
            importAlertMessage = "课表导入失败\n\(error.localizedDescription)"
            importErrorRetryAction = { Task { await self.importCourses() } }
            showImportAlert    = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            isImporting = false
        }
    }

    private func fetchCoursesWithMFA() async throws -> (courses: [Course], startDate: Date?)
    {
        do
        {
            return try await CurriculumService.fetchCourses(
                username: userinfo.username,
                password: userinfo.encryptedPasswordShishanyouni,
                token:    userinfo.shishanyouniToken,
                year:     selectedYear,
                term:     selectedTerm
            )
        }
        catch ShishanyouniAPIError.needMFA(let phone, let sessionId, _)
        {
            try await refreshShishanyouniToken(phone: phone, sessionId: sessionId)
            return try await CurriculumService.fetchCourses(
                username: userinfo.username,
                password: userinfo.encryptedPasswordShishanyouni,
                token:    userinfo.shishanyouniToken,
                year:     selectedYear,
                term:     selectedTerm
            )
        }
    }

    /// 使用当前账号的 CAS 教务会话补齐课程考核方式。
    ///
    /// 这一步是“增强信息”而不是导入课表的前置条件：教务接口暂时不可用、
    /// Cookie 失效或用户取消 MFA 时，仍返回没有考核方式的原课程数组。
    private func attachAssessmentMethods(to importedCourses: [Course]) async -> [Course]
    {
        guard !importedCourses.isEmpty,
              !userinfo.username.isEmpty,
              !userinfo.encryptedPasswordSchool.isEmpty
        else
        {
            print("ℹ️ 未补充考核方式：当前账号没有可用的教务认证信息")
            return importedCourses
        }

        do
        {
            let query = ScheduleQuery()
            let cookie = try await query.loginAndGetCookie(
                username: userinfo.username,
                rsaPassword: userinfo.encryptedPasswordSchool,
                mfaCodeProvider: { maskedPhone in
                    await self.requestCASMFACode(maskedPhone: maskedPhone)
                }
            )

            let methods = try await CurriculumAssessmentService.fetchAssessmentMethods(
                cookie: cookie,
                year: selectedYear,
                appTerm: selectedTerm
            )

            guard !methods.isEmpty else
            {
                print("ℹ️ 教务未返回可展示的考试/考查字段")
                return importedCourses
            }

            return importedCourses.map
            { course in
                var enriched = course
                // 手动添加的课程没有教务课程名，不会被误匹配。
                enriched.assessmentMethod = methods[course.name]
                return enriched
            }
        }
        catch
        {
            print("⚠️ 考核方式补充失败：\(error.localizedDescription)，不影响课表导入")
            return importedCourses
        }
    }

    private func refreshShishanyouniToken(phone: String, sessionId: String) async throws
    {
        guard let smsCode = await requestShishanyouniMFACode(maskedPhone: phone, sessionId: sessionId),
              !smsCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else
        {
            throw ShishanyouniAPIError.apiError(code: 22, message: "已取消短信验证码验证。")
        }

        let token = try await ShishanyouniMFAFlow.submitCode(sessionId: sessionId, smsCode: smsCode)
        await MainActor.run
        {
            userinfo.updateShishanyouniToken(token)
        }
    }

    /// 为 CAS 教务登录提供验证码输入界面。
    /// ScheduleQuery 会把当前会话的“发送验证码”动作放进 MFACodeContext，
    /// 这里仅负责把它交给现有的 MFA Sheet，不重复实现发送协议。
    @MainActor
    private func requestCASMFACode(maskedPhone: String?) async -> String?
    {
        mfaMaskedPhone = maskedPhone ?? ""
        mfaCode = ""
        mfaSendCodeAction = MFACodeContext.activeSendCodeAction
        await Task.yield()
        showMFASheet = true

        return await withCheckedContinuation
        { continuation in
            mfaContinuation = continuation
        }
    }

    @MainActor
    private func requestShishanyouniMFACode(maskedPhone: String, sessionId: String) async -> String?
    {
        mfaMaskedPhone = maskedPhone
        mfaCode = ""
        mfaSendCodeAction = { await ShishanyouniMFAFlow.sendCodeMessage(sessionId: sessionId) }
        await Task.yield()
        showMFASheet = true
        return await withCheckedContinuation
        { continuation in
            mfaContinuation = continuation
        }
    }

    @MainActor
    private func resolveMFACode(_ code: String?)
    {
        showMFASheet = false
        mfaContinuation?.resume(returning: code)
        mfaContinuation = nil
        mfaSendCodeAction = nil
    }

    // MARK: - 持久化

    private func persistCourses(_ courses: [Course]) {
        CurriculumStore.shared.saveCourses(courses, semesterStart: nil)
        print("✅ 课表已保存到共享存储，共 \(courses.count) 条")
    }

    /// 将拉取结果写入 courses，keepManual 决定是否保留手动课程
    private func applyImport(_ result: (courses: [Course], startDate: Date?), keepManual: Bool) {
        let manual = keepManual ? courses.filter { $0.isManual } : []
        courses = manual + result.courses
        persistCourses(courses)
        hasPendingImportedSchedule = true

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
        hasUserSelectedDate || hasSelectedPhoto
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

    /// 学年从每年 8 月 1 日开始：8 月至次年 1 月为秋季，2 月至 7 月为同一学年的春季。
    private static func defaultImportSemester(for date: Date, calendar: Calendar = .current) -> (year: String, term: String) {
        let components = calendar.dateComponents([.year, .month], from: date)
        let calendarYear = components.year ?? calendar.component(.year, from: Date())
        let month = components.month ?? 8
        let isAutumnTerm = month >= 8
        let academicYearStart = isAutumnTerm ? calendarYear : calendarYear - 1

        return (year: String(academicYearStart), term: isAutumnTerm ? "1" : "2")
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
            if let sharedDir = CurriculumWidgetSync.appGroupContainerURL() {
                let sharedURL = sharedDir.appendingPathComponent(filename)
                try? data.write(to: sharedURL)
            }
            CurriculumWidgetSync.saveBackgroundMetadata(filename: filename, opacity: backgroundOpacity)
        } catch {
            print("Failed to save background image: \(error)")
        }
    }
    
    private func clearBackgroundImage() {
        if !backgroundImageFilename.isEmpty {
            let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(backgroundImageFilename)
            try? FileManager.default.removeItem(at: fileURL)

            if let sharedDir = CurriculumWidgetSync.appGroupContainerURL() {
                let sharedURL = sharedDir.appendingPathComponent(backgroundImageFilename)
                try? FileManager.default.removeItem(at: sharedURL)
            }
            backgroundImageFilename = ""
            CurriculumWidgetSync.clearBackgroundMetadata()
        }
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
}
