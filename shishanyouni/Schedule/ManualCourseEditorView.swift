//
//  ManualCourseEditorView.swift
//  shishanyouni
//
//  Created by 寒海澜沧 on 2026/3/15.

import Foundation
import SwiftUI

enum CourseEditorMode
{
    case add(prefillWeekday: Int = 1, prefillPeriod: Int = 1)
    case edit(Course)

    var title: String
    {
        switch self
        {
        case .add: return "手动添加课程"
        case .edit: return "编辑课程"
        }
    }

    var buttonTitle: String
    {
        switch self
        {
        case .add: return "添加"
        case .edit: return "保存"
        }
    }
}

struct SimpleWeekButton: View
{
    let week: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View
    {
        Button(action: {
            DispatchQueue.main.async
            {
                action()
            }
        })
        {
            Text("\(week)")
                .font(.caption)
                .frame(width: 35, height: 35)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Circle())
        }
        .buttonStyle(BorderlessButtonStyle())
        .contentShape(Rectangle())
    }
}

struct ManualCourseEditorView: View
{
    @Environment(\.dismiss) var dismiss
    @Binding var courses: [Course]

    let mode: CourseEditorMode

    // 表单数据
    @State private var courseName: String = ""
    @State private var selectedWeekday: Int = 1
    @State private var startPeriod: Int = 1
    @State private var endPeriod: Int = 2
    @State private var location: String = ""
    @State private var teacherName: String = ""
    @State private var selectedWeeks: Set<Int> = []
    @State private var selectedColor: Color = .blue
    @State private var hasCustomColor: Bool = false

    let weekdays = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
    let periods = Array(1 ... 12)
    let maxWeek = 30

    init(courses: Binding<[Course]>, mode: CourseEditorMode)
    {
        _courses = courses
        self.mode = mode

        switch mode
        {
        case let .add(weekday, period):
            _selectedWeekday = State(initialValue: weekday)
            _startPeriod = State(initialValue: period)
            _endPeriod = State(initialValue: min(period + 1, 12))

        case let .edit(course):
            _courseName = State(initialValue: course.name)
            _selectedWeekday = State(initialValue: course.day)
            _location = State(initialValue: course.room ?? "")
            _teacherName = State(initialValue: course.teacher ?? "")
            _selectedWeeks = State(initialValue: Set(course.weekList))
            _startPeriod = State(initialValue: course.start)
            _endPeriod = State(initialValue: course.endPeriod)
            if let hex = course.customColorHex, let c = Color(hex: hex) {
                _selectedColor = State(initialValue: c)
                _hasCustomColor = State(initialValue: true)
            }
        }
    }

    var body: some View
    {
        NavigationStack
        {
            Form
            {
                // 基本信息
                Section("课程信息")
                {
                    HStack
                    {
                        Text("课程名称")
                        Spacer()
                        TextField("输入课程名称", text: $courseName)
                            .multilineTextAlignment(.trailing)
                    }

                    Picker("星期", selection: $selectedWeekday)
                    {
                        ForEach(1 ... 7, id: \.self)
                        { index in
                            Text(weekdays[index - 1]).tag(index)
                        }
                    }

                    Picker("开始节次", selection: $startPeriod)
                    {
                        ForEach(periods, id: \.self)
                        { p in
                            Text("第\(p)节").tag(p)
                        }
                    }
                    .onChange(of: startPeriod)
                    { newValue in
                        if newValue > endPeriod
                        {
                            endPeriod = newValue
                        }
                    }

                    Picker("结束节次", selection: $endPeriod)
                    {
                        ForEach(periods, id: \.self)
                        { p in
                            Text("第\(p)节").tag(p)
                        }
                    }
                    .onChange(of: endPeriod)
                    { newValue in
                        if newValue < startPeriod
                        {
                            startPeriod = newValue
                        }
                    }

                    if startPeriod > endPeriod
                    {
                        Text("开始节次不能大于结束节次")
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    HStack
                    {
                        Text("教室")
                        Spacer()
                        TextField("可选", text: $location)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack
                    {
                        Text("教师")
                        Spacer()
                        TextField("可选", text: $teacherName)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack
                    {
                        Text("课程颜色")
                        Spacer()
                        if hasCustomColor
                        {
                            Button("重置")
                            {
                                hasCustomColor = false
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.trailing, 6)
                        }
                        ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                            .labelsHidden()
                            .onChange(of: selectedColor) { _ in hasCustomColor = true }
                    }
                }

                // 周次选择
                Section("上课周次")
                {
                    // 快捷选择行
                    HStack
                    {
                        Spacer()
                        Button("本学期") { selectedWeeks = Set(1 ... 20) }.buttonStyle(.bordered)
                        Button("1-11周") { selectedWeeks = Set(1 ... 11) }.buttonStyle(.bordered)
                        Button("12-19周") { selectedWeeks = Set(12 ... 19) }.buttonStyle(.bordered)
                        Spacer()
                    }
                    .font(.caption)
                    .listRowSeparator(.hidden)

                    // 周次格子
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8)
                    {
                        ForEach(1 ... maxWeek, id: \.self)
                        { week in
                            SimpleWeekButton(
                                week: week,
                                isSelected: selectedWeeks.contains(week),
                                action: {
                                    if selectedWeeks.contains(week)
                                    {
                                        selectedWeeks.remove(week)
                                    }
                                    else
                                    {
                                        selectedWeeks.insert(week)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowSeparator(.hidden)

                    // 单双周过滤（在已选周次中保留奇/偶）
                    HStack
                    {
                        Spacer()
                        Button("单周") { selectedWeeks = selectedWeeks.filter { $0 % 2 != 0 } }
                            .buttonStyle(.bordered)
                        Button("双周") { selectedWeeks = selectedWeeks.filter { $0 % 2 == 0 } }
                            .buttonStyle(.bordered)
                        Spacer()
                    }
                    .font(.caption)
                    .listRowSeparator(.hidden)

                    HStack
                    {
                        Spacer()
                        Button("全部清空") { selectedWeeks.removeAll() }
                            .buttonStyle(.automatic)
                            .foregroundStyle(Color.red)
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                }

                // 预览
                Section("预览")
                {
                    VStack(alignment: .leading, spacing: 8)
                    {
                        Text(courseName.isEmpty ? "未命名课程" : courseName)
                            .font(.headline)

                        HStack
                        {
                            Label(weekdays[selectedWeekday - 1], systemImage: "calendar")
                            Text("第\(startPeriod)-\(endPeriod)节")
                        }
                        .font(.subheadline)

                        if !location.isEmpty
                        {
                            Label(location, systemImage: "location").font(.subheadline)
                        }

                        if !teacherName.isEmpty
                        {
                            Label(teacherName, systemImage: "person").font(.subheadline)
                        }

                        Text("周次: \(selectedWeeks.sorted().map { "\($0)" }.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(mode.title)
            #if !os(macOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar
                {
                    ToolbarItem(placement: .cancellationAction)
                    {
                        Button("取消") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction)
                    {
                        Button(mode.buttonTitle) { saveCourse() }
                            .disabled(!isFormValid)
                    }
                }
        }
    }

    private var isFormValid: Bool
    {
        !courseName.isEmpty && startPeriod <= endPeriod && !selectedWeeks.isEmpty
    }

    private func saveCourse()
    {
        switch mode
        {
        case .add:
            addNewCourse()
        case let .edit(editingCourse):
            updateCourse(editingCourse)
        }
        persistCourses()
        dismiss()
    }

    private func addNewCourse()
    {
        let hex = hasCustomColor ? selectedColor.toHex() : nil
        let newCourse = Course.createManualCourse(
            name: courseName,
            weekday: selectedWeekday,
            startPeriod: startPeriod,
            endPeriod: endPeriod,
            weeks: selectedWeeks,
            location: location.isEmpty ? nil : location,
            teacher: teacherName.isEmpty ? nil : teacherName,
            customColorHex: hex
        )
        courses.append(newCourse)
        print("✅ 课程添加成功: \(courseName)")
    }

    private func updateCourse(_ editing: Course)
    {
        // ── 0. 精确定位当前编辑的课程条目 ──
        // 旧版本的 ID 可能存在重复（同名课程不同 step 生成了相同 ID），
        // 因此除了 id 还要比对 day/start/step/weekList 确保找到正确条目。
        guard let index = courses.firstIndex(where: {
            $0.id == editing.id
            && $0.day == editing.day
            && $0.start == editing.start
            && $0.step == editing.step
            && $0.weekList == editing.weekList
        }) ?? courses.firstIndex(where: { $0.id == editing.id }) // 兜底：仅按 id 匹配
        else { return }

        let sortedWeeks = selectedWeeks.sorted()
        let weeksText = sortedWeeks.map { "\($0)" }.joined(separator: ",") + "周"

        // ── 1. 判断颜色是否发生了变化 ──
        let newColorHex: String? = hasCustomColor ? selectedColor.toHex() : nil
        let oldColorHex = editing.customColorHex
        let oldColorRandom = editing.colorRandom

        let colorChanged: Bool = {
            if newColorHex != oldColorHex { return true }
            // 如果从自定义色"重置"回随机色，也算变化
            if oldColorHex != nil && newColorHex == nil { return true }
            return false
        }()

        // ── 2. 更新当前编辑的这条记录 ──
        let updated = Course(
            id: editing.id,
            name: courseName,
            day: selectedWeekday,
            start: startPeriod,
            step: endPeriod - startPeriod + 1,
            room: location.isEmpty ? nil : location,
            teacher: teacherName.isEmpty ? nil : teacherName,
            weekList: sortedWeeks,
            weeks: weeksText,
            term: editing.term,
            colorRandom: editing.colorRandom,
            customColorHex: newColorHex,
            isManual: editing.isManual
        )
        courses[index] = updated

        // ── 3. 如果颜色改变了，同步所有同名课程的颜色 ──
        // 同一门课在不同时间段会有不同的 id，但 name 相同
        if colorChanged
        {
            let targetName = editing.name  // 用编辑前的原名匹配
            for i in courses.indices
            {
                // 按数组下标跳过刚更新的那条（而非按 id，因为旧数据可能存在重复 id）
                guard i != index else { continue }
                // 匹配同名课程
                guard courses[i].name == targetName else { continue }

                courses[i].customColorHex = newColorHex
                // 如果重置了自定义色，也把 colorRandom 统一
                if newColorHex == nil
                {
                    courses[i].colorRandom = oldColorRandom
                }
            }
            let syncCount = courses.filter { $0.name == targetName }.count
            print("🎨 已同步颜色到所有「\(targetName)」课程，共 \(syncCount) 条")
        }

        // ── 4. 如果课程名称也改了，同样需要考虑是否同步 ──
        // （这里只同步颜色，名称修改属于单条编辑，不扩散）

        print("✅ 课程更新成功: \(courseName)")
    }

    private func persistCourses()
    {
        ScheduleSharedStore.saveCourses(courses)
        print("✅ 课程保存成功，共 \(courses.count) 门")
    }
}

struct ManualCourseEditorPreview: View
{
    @State private var courses: [Course] = []

    var body: some View
    {
        NavigationStack
        {
            ManualCourseEditorView(courses: $courses, mode: .add())
        }
    }
}

#Preview("可输入的预览")
{
    ManualCourseEditorPreview()
        .environmentObject(userInfo())
}

// MARK: - 预览

#Preview("添加模式")
{
    ManualCourseEditorView(courses: .constant([]), mode: .add())
}

#Preview("编辑模式")
{
    let sample = Course.createManualCourse(
        name: "高等数学 A",
        weekday: 1,
        startPeriod: 1,
        endPeriod: 3,
        weeks: Set(1 ... 16),
        location: "三教A101",
        teacher: "张教授"
    )
    ManualCourseEditorView(courses: .constant([sample]), mode: .edit(sample))
}
