//
//  ScheduleSettingView.swift
//  shishanyouni
//
//  Originally by douer_lucky on 2026/2/11.
//  Refactored: uses new ScheduleService (lion.hzau.edu.cn iOS API).
//

import SwiftUI

struct ScheduleSettingView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var userinfo: userInfo

    @Binding var semesterStartDate: Date
    @Binding var courses: [Course]

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

    // 导入学期选择
    @State private var selectedYear     = "2025"       // 学年起始年份
    @State private var selectedTerm     = "2"          // "1"=秋季, "2"=春季

    @AppStorage("semesterStartDateTimestamp") private var savedTimestamp: Double = 0

    /// 学年显示列表（picker 用）
    private let availableYears  = ["2023", "2024", "2025", "2026"]
    private let terms           = [("秋季学期", "1"), ("春季学期", "2")]

    // MARK: - body

    var body: some View {
        NavigationStack {
            Form {

                // ── 学期开学日期 ──
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
                } header: {
                    Text("学期设置")
                }

                // ── 课表导入 ──
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
                } header: {
                    Text("课表导入")
                }

                // ── 清空课表 ──
                if !courses.isEmpty {
                    Section {
                        Button(role: .destructive) {
                            showClearConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("清空课表").fontWeight(.semibold)
                                Spacer()
                            }
                        }
                    } footer: {
                        Text("当前已有 \(courses.count) 门课程").font(.caption)
                    }
                }

                // ── 保存设置 ──
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
                    .disabled(!hasUserSelectedDate)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
            // ── 弹窗 ──
            .sheet(isPresented: $showImportPicker) { importPickerView }
            .alert("设置已保存", isPresented: $showSaveConfirmation) {
                Button("确定", role: .cancel) { dismiss() }
            } message: {
                Text("开学日期已更新为 \(formatDate(tempStartDate))")
            }
            .alert(importAlertMessage, isPresented: $showImportAlert) {
                Button("确定", role: .cancel) {}
            }
            .alert("确认清空课表", isPresented: $showClearConfirmation) {
                Button("取消", role: .cancel) {}
                Button("清空", role: .destructive) { clearCourses() }
            } message: {
                Text("此操作将删除所有已导入的课程，是否继续？")
            }
        }
    }

    // MARK: - 导入选择器视图

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
                password: plainPassword,
                year:     selectedYear,
                term:     selectedTerm
            )

            courses       = result.courses
            importedCount = result.courses.count
            persistCourses(result.courses)

            // 若 API 返回了开学日期，自动填入日期选择器
            if let apiDate = result.startDate {
                tempStartDate       = apiDate
                hasUserSelectedDate = true
                importAlertMessage  = "课表导入成功\n已获取 \(importedCount) 条排课\n开学日期已自动填写为 \(formatDate(apiDate))，请确认后保存"
            } else {
                importAlertMessage  = "课表导入成功\n已获取 \(importedCount) 条排课\n请手动设置开学日期后保存"
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showImportAlert = true

        } catch {
            print("❌ 导入失败: \(error)")
            importAlertMessage = "课表导入失败\n\(error.localizedDescription)"
            showImportAlert    = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }

        isImporting = false
    }

    // MARK: - 持久化

    private func persistCourses(_ courses: [Course]) {
        do {
            let data = try JSONEncoder().encode(courses)
            UserDefaults.standard.set(data, forKey: "saved_courses")
            print("✅ 课表已保存到本地，共 \(courses.count) 条")
        } catch {
            print("❌ 课表本地保存失败: \(error)")
        }
    }

    private func clearCourses() {
        courses = []
        UserDefaults.standard.removeObject(forKey: "saved_courses")
        print("✅ 课表已清空")
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
        showSaveConfirmation = true
    }

    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale     = Locale(identifier: "zh_CN")
        fmt.dateFormat = "yyyy年MM月dd日 (EEEE)"
        return fmt.string(from: date)
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
