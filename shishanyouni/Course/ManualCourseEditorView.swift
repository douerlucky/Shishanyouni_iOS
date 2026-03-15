//
//  ManualCourseEditorView.swift
//  shishanyouni
//
//  Created by 寒海澜沧 on 2026/3/15.

import SwiftUI

enum CourseEditorMode {
    case add
    case edit(Course)
    
    var title: String {
        switch self {
        case .add: return "手动添加课程"
        case .edit: return "编辑课程"
        }
    }
    
    var buttonTitle: String {
        switch self {
        case .add: return "添加"
        case .edit: return "保存"
        }
    }
}

struct ManualCourseEditorView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var courses: [Course]
    
    let mode: CourseEditorMode
    
    // 表单数据
    @State private var courseName: String
    @State private var selectedWeekday: Int
    @State private var startPeriod: Int
    @State private var endPeriod: Int
    @State private var location: String
    @State private var teacher: String
    @State private var selectedWeeks: Set<Int>
    
    // 周次选择相关
    let weekdays = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
    let periods = Array(1...12)
    let maxWeek = 30
    
    // 初始化
    init(courses: Binding<[Course]>, mode: CourseEditorMode) {
        self._courses = courses
        self.mode = mode
        
        // 根据模式初始化表单数据
        switch mode {
        case .add:
            _courseName = State(initialValue: "")
            _selectedWeekday = State(initialValue: 1)
            _location = State(initialValue: "")
            _teacher = State(initialValue: "")
            _selectedWeeks = State(initialValue: [])
            _startPeriod = State(initialValue: 1)
            _endPeriod = State(initialValue: 2)
            
        case .edit(let course):
            _courseName = State(initialValue: course.kcmc)
            _selectedWeekday = State(initialValue: Int(course.xqj) ?? 1)
            _location = State(initialValue: course.cdmc ?? "")
            _teacher = State(initialValue: course.xm ?? "")
            _selectedWeeks = State(initialValue: course.parsedWeeks)
            
            // 解析节次
            let jcsParts = course.jcs.split(separator: "-")
            if jcsParts.count == 2,
               let start = Int(jcsParts[0]),
               let end = Int(jcsParts[1]) {
                _startPeriod = State(initialValue: start)
                _endPeriod = State(initialValue: end)
            } else {
                _startPeriod = State(initialValue: 1)
                _endPeriod = State(initialValue: 2)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // 基本信息
                Section("课程信息") {
                    TextField("课程名称", text: $courseName)
                    
                    Picker("星期", selection: $selectedWeekday) {
                        ForEach(1...7, id: \.self) { index in
                            Text(weekdays[index - 1]).tag(index)
                        }
                    }
                    
                    HStack {
                        Picker("开始节次", selection: $startPeriod) {
                            ForEach(periods, id: \.self) { period in
                                Text("第\(period)节").tag(period)
                            }
                        }
                        
                        Text("至")
                        
                        Picker("结束节次", selection: $endPeriod) {
                            ForEach(periods, id: \.self) { period in
                                Text("第\(period)节").tag(period)
                            }
                        }
                    }
                    
                    TextField("教室（可选）", text: $location)
                    TextField("教师（可选）", text: $teacher)
                }
                
                // 周次选择
                Section("上课周次") {
                    // 快捷选择按钮
                    HStack {
                        Button("全选") {
                            selectedWeeks = Set(1...maxWeek)
                        }
                        .buttonStyle(.bordered)
                        
                        Button("全部清空") {
                            selectedWeeks.removeAll()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("本学期") {
                            selectedWeeks = Set(1...20)
                        }
                        .buttonStyle(.bordered)
                    }
                    .font(.caption)
                    
                    // 周次网格
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                        ForEach(1...maxWeek, id: \.self) { week in
                            WeekButton(
                                week: week,
                                isSelected: selectedWeeks.contains(week),
                                action: {
                                    if selectedWeeks.contains(week) {
                                        selectedWeeks.remove(week)
                                    } else {
                                        selectedWeeks.insert(week)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // 预览
                Section("预览") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(courseName.isEmpty ? "未命名课程" : courseName)
                            .font(.headline)
                        
                        HStack {
                            Label(weekdays[selectedWeekday - 1], systemImage: "calendar")
                            Text("第\(startPeriod)-\(endPeriod)节")
                        }
                        .font(.subheadline)
                        
                        if !location.isEmpty {
                            Label(location, systemImage: "location")
                                .font(.subheadline)
                        }
                        
                        if !teacher.isEmpty {
                            Label(teacher, systemImage: "person")
                                .font(.subheadline)
                        }
                        
                        Text("周次: \(selectedWeeks.sorted().map { "\($0)" }.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(mode.buttonTitle) {
                        saveCourse()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !courseName.isEmpty &&
        startPeriod <= endPeriod &&
        !selectedWeeks.isEmpty
    }
    
    private func saveCourse() {
        switch mode {
        case .add:
            addNewCourse()
        case .edit(let editingCourse):
            updateCourse(editingCourse)
        }
        
        saveCourses()
        dismiss()
    }
    
    private func addNewCourse() {
        let newCourse = Course.createManualCourse(
            name: courseName,
            weekday: selectedWeekday,
            startPeriod: startPeriod,
            endPeriod: endPeriod,
            weeks: selectedWeeks,
            location: location.isEmpty ? nil : location,
            teacher: teacher.isEmpty ? nil : teacher
        )
        courses.append(newCourse)
        print("✅ 课程添加成功: \(courseName)")
    }
    
    private func updateCourse(_ editingCourse: Course) {
        if let index = courses.firstIndex(where: { $0.id == editingCourse.id }) {
            let updatedCourse = Course(
                jxb_id: editingCourse.jxb_id,
                kch_id: editingCourse.kch_id,
                kcmc: courseName,
                xqj: "\(selectedWeekday)",
                jcs: "\(startPeriod)-\(endPeriod)",
                cdmc: location.isEmpty ? nil : location,
                xm: teacher.isEmpty ? nil : teacher,
                zcmc: editingCourse.zcmc,
                jxbzc: editingCourse.jxbzc,
                zcd: selectedWeeks.sorted().map { "\($0)" }.joined(separator: ",") + "周",
                xqjmc: editingCourse.xqjmc,
                colorIndex: editingCourse.colorIndex,
                isManual: true
            )
            courses[index] = updatedCourse
            print("✅ 课程更新成功: \(courseName)")
        }
    }
    
    private func saveCourses() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(courses)
            UserDefaults.standard.set(data, forKey: "saved_courses")
            print("✅ 课程保存成功，共 \(courses.count) 门")
        } catch {
            print("❌ 保存失败: \(error)")
        }
    }
}
// MARK: - 预览

#Preview("添加模式") {
    // 创建示例数据
    let sampleCourses: [Course] = []
    
    NavigationStack {  // 移除 return
        ManualCourseEditorView(
            courses: .constant(sampleCourses),
            mode: .add
        )
    }
}

#Preview("编辑模式 - 完整课程") {
    // 创建一个完整的示例课程
    let sampleCourse = Course.createManualCourse(
        name: "高等数学 A",
        weekday: 1,
        startPeriod: 1,
        endPeriod: 3,
        weeks: [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16],
        location: "三教A101",
        teacher: "张教授"
    )
    
    // 创建一个包含该课程的数组
    let coursesWithSample = [sampleCourse]
    
    NavigationStack {  // 移除 return
        ManualCourseEditorView(
            courses: .constant(coursesWithSample),
            mode: .edit(sampleCourse)
        )
    }
}
