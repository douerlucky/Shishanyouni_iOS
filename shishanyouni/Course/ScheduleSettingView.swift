//
//  ScheduleSettingView.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/11.
//

import SwiftUI

struct ScheduleSettingView: View
{
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var userinfo: userInfo
    @Binding var semesterStartDate: Date
    @Binding var courses: [Course]

    @State private var tempStartDate: Date = Date()
    @State private var hasUserSelectedDate: Bool = false
    @State private var showSaveConfirmation = false
    @State private var showImportPicker = false
    @State private var showImportAlert = false
    @State private var showClearConfirmation = false
    @State private var importAlertMessage = ""
    @State private var isImporting = false
    @State private var importedCoursesCount = 0

    // 导入选择器相关状态
    @State private var selectedYear = "2025-2026"
    @State private var selectedSemester = "秋季学期"

    @AppStorage("semesterStartDateTimestamp") private var savedTimestamp: Double = 0

    let availableYears = ["2024-2025", "2025-2026", "2026-2027"]
    let semesters = ["秋季学期", "春季学期"]

    init(semesterStartDate: Binding<Date>, courses: Binding<[Course]>)
    {
        _semesterStartDate = semesterStartDate
        _courses = courses
        // 不自动填充日期，使用当前日期作为DatePicker的初始值
        // 但用户必须主动选择才会被标记为已选择
    }

    var body: some View
    {
        NavigationStack
        {
            Form
            {
                Section
                {
                    DatePicker(
                        "本学期开学日期",
                        selection: $tempStartDate,
                        displayedComponents: [.date]
                    )
                    .environment(\.locale, Locale(identifier: "zh_CN"))
                    .onChange(of: tempStartDate)
                    { newValue in
                        hasUserSelectedDate = true
                        adjustToMonday(newValue)
                    }
                } header: {
                    Text("学期设置")
                }

                Section
                {
                    Button(action: {
                        showImportPicker = true
                    })
                    {
                        if userinfo.username.isEmpty
                        {
                            Text("请先在个人页面登录")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        else
                        {
                            HStack
                            {
                                Spacer()
                                if isImporting
                                {
                                    ProgressView()
                                        .padding(.trailing, 8)
                                }
                                Text(isImporting ? "导入中..." : "导入课表")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                    }
                    .disabled(userinfo.username.isEmpty || isImporting)

                } header: {
                    Text("课表导入")
                }
                Section
                {
                    if !courses.isEmpty
                    {
                        Button(role: .destructive, action: {
                            showClearConfirmation = true
                        })
                        {
                            HStack
                            {
                                Spacer()
                                Text("清空课表")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                    }
                }
                footer: {
                    if !courses.isEmpty
                    {
                        Text("当前已有 \(courses.count) 门课程")
                            .font(.caption)
                    }
                }

                Section
                {
                    Button(action: {
                        saveSettings()
                    })
                    {
                        HStack
                        {
                            Spacer()
                            Text("保存设置")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!hasUserSelectedDate || tempStartDate == semesterStartDate)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar
            {
                ToolbarItem(placement: .navigationBarLeading)
                {
                    Button(action: {
                        dismiss()
                    })
                    {
                        Image(systemName: "xmark")
                    }
                }
            }
            .sheet(isPresented: $showImportPicker)
            {
                importPickerView
            }
            .alert("设置已保存", isPresented: $showSaveConfirmation)
            {
                Button("确定", role: .cancel)
                {
                    dismiss()
                }
            } message: {
                Text("开学日期已更新为 \(formatDate(tempStartDate))")
            }
            .alert(importAlertMessage, isPresented: $showImportAlert)
            {
                Button("确定", role: .cancel) {}
            }
            .alert("确认清空课表", isPresented: $showClearConfirmation)
            {
                Button("取消", role: .cancel) {}
                Button("清空", role: .destructive)
                {
                    clearCourses()
                }
            } message: {
                Text("此操作将删除所有已导入的课程，是否继续？")
            }
        }
    }

    // 导入选择器视图
    private var importPickerView: some View
    {
        NavigationStack
        {
            VStack(spacing: 20)
            {
                Text("选择导入学期")
                    .font(.headline)
                    .padding(.top, 20)

                HStack(spacing: 20)
                {
                    // 学年选择
                    Picker("学年", selection: $selectedYear)
                    {
                        ForEach(availableYears, id: \.self)
                        { year in
                            Text(year).tag(year)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)

                    // 学期选择
                    Picker("学期", selection: $selectedSemester)
                    {
                        ForEach(semesters, id: \.self)
                        { semester in
                            Text(semester).tag(semester)
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
            .toolbar
            {
                ToolbarItem(placement: .navigationBarLeading)
                {
                    Button("取消")
                    {
                        showImportPicker = false
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing)
                {
                    Button("确认")
                    {
                        showImportPicker = false
                        Task
                        {
                            await importCourses()
                        }
                    }
                    .disabled(isImporting)
                }
            }
        }
    }

    // 导入课表
    private func importCourses() async
    {
        isImporting = true

        // 解析学年和学期参数
        let yearComponents = selectedYear.split(separator: "-")
        guard yearComponents.count == 2,
              let startYear = Int(yearComponents[0])
        else
        {
            importAlertMessage = "课表导入失败\n学年格式错误"
            showImportAlert = true
            isImporting = false
            return
        }

        let xnm = String(startYear)
        let xqm = selectedSemester == "秋季学期" ? "3" : "12"

        do
        {
            // 检查是否已登录
            guard !userinfo.username.isEmpty,
                  !userinfo.encryptedResult.isEmpty
            else
            {
                importAlertMessage = "课表导入失败\n请先登录"
                showImportAlert = true
                isImporting = false
                return
            }

            // 先登录获取 Cookie
            let scheduleQuery = ScheduleQuery()
            let cookie = try await scheduleQuery.loginAndGetCookie(
                username: userinfo.username,
                rsaPassword: userinfo.encryptedResult
            )

            // 查询课表
            let fetchedCourses = try await scheduleQuery.fetchCourses(
                cookie: cookie,
                xnm: xnm,
                xqm: xqm
            )

            importedCoursesCount = fetchedCourses.count
            courses = fetchedCourses

            // 保存课表到本地
            saveCourses(fetchedCourses)

            importAlertMessage = "课表导入成功\n已获取 \(importedCoursesCount) 门课程\n请记得调整开学时间"
            showImportAlert = true
        }
        catch
        {
            print("导入失败: \(error)")
            importAlertMessage = "课表导入失败\n\(error.localizedDescription)"
            showImportAlert = true
        }

        isImporting = false
    }

    // 保存课表到本地
    private func saveCourses(_ courses: [Course])
    {
        do
        {
            let encoder = JSONEncoder()
            let data = try encoder.encode(courses)
            UserDefaults.standard.set(data, forKey: "saved_courses")
            print("✅ 课表已保存到本地")
        }
        catch
        {
            print("❌ 课表保存失败: \(error)")
        }
    }

    // 清空课表
    private func clearCourses()
    {
        courses = []
        UserDefaults.standard.removeObject(forKey: "saved_courses")
        print("✅ 课表已清空")
    }

    private func adjustToMonday(_ date: Date)
    {
        var calendar = Calendar.current
        calendar.firstWeekday = 2

        let weekday = calendar.component(.weekday, from: date)

        if weekday != 2
        {
            let daysToSubtract: Int
            if weekday == 1
            {
                daysToSubtract = 6
            }
            else
            {
                daysToSubtract = weekday - 2
            }

            if let monday = calendar.date(byAdding: .day, value: -daysToSubtract, to: date)
            {
                tempStartDate = monday
            }
        }
    }

    private func saveSettings()
    {
        semesterStartDate = tempStartDate
        savedTimestamp = tempStartDate.timeIntervalSince1970
        showSaveConfirmation = true
    }

    private func formatDate(_ date: Date) -> String
    {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年MM月dd日 (EEEE)"
        return formatter.string(from: date)
    }
}

#Preview
{
    ScheduleSettingView(
        semesterStartDate: .constant(Date()),
        courses: .constant([])
    )
    .environmentObject(userInfo())
}
