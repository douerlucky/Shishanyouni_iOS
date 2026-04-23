//
//  AllScheduleSetting.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/4/23.
//

import SwiftUI
import UIKit

struct AllScheduleSetting: View
{
    @State private var courses: [Course] = []
    @State private var backgroundImage: UIImage?
    @State private var addCourseContext: AddCourseContext?
    @State private var editingCourse: Course?
    @State private var pendingDeleteCourse: Course?
    @State private var showDeleteConfirm = false
    @AppStorage("scheduleBackgroundImageFilename") private var backgroundImageFilename: String = ""
    @AppStorage("scheduleBackgroundOpacity") private var backgroundOpacity: Double = 0.2
    @AppStorage("scheduleContentOpacity") private var scheduleContentOpacity: Double = 1.0
    @AppStorage("enableLiquidGlassEffect") private var enableLiquidGlassEffect: Bool = false
    

    var body: some View
    {
        ZStack
        {
            if let backgroundImage
            {
                Image(uiImage: backgroundImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .opacity(backgroundOpacity)
            }

            List
            {
                if courses.isEmpty
                {
                    Text("暂无已导入课程")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 40)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                else
                {
                    ForEach(courses)
                    { course in
                        courseCard(course)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false)
                            {
                                Button(role: .destructive)
                                {
                                    pendingDeleteCourse = course
                                    showDeleteConfirm = true
                                }
                                label:
                                {
                                    Label("删除", systemImage: "trash")
                                }
                                Button
                                {
                                    editingCourse = course
                                }
                                label:
                                {
                                    Label("编辑", systemImage: "pencil")
                                }
                                .tint(.blue)


                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .top)
            {
                Color.clear.frame(height: 60)
            }
            .safeAreaInset(edge: .bottom)
            {
                Color.clear.frame(height: 60)
            }
        }
        .navigationTitle("所有课程")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar
        {
            ToolbarItem(placement: .navigationBarTrailing)
            {
                Button(action: { addCourseContext = AddCourseContext(day: 1, period: 1) })
                { Image(systemName: "plus.circle").fontWeight(.medium) }
            }
        }
        
        .onAppear
        {
            loadSavedCourses()
            loadBackgroundImage()
        }
        .onChange(of: backgroundImageFilename)
        { _ in
            loadBackgroundImage()
        }
        .sheet(item: $editingCourse, onDismiss: {
            sortCoursesByNameAndTime()
            saveCourses()
        })
        { course in
            ManualCourseEditorView(courses: $courses, mode: .edit(course))
        }
        .sheet(item: $addCourseContext)
        { context in
            ManualCourseEditorView(
                courses: $courses,
                mode: .add(prefillWeekday: context.day, prefillPeriod: context.period)
            )
        }
        .alert("确认删除课程", isPresented: $showDeleteConfirm)
        {
            Button("取消", role: .cancel)
            {
                pendingDeleteCourse = nil
            }
            Button("删除", role: .destructive)
            {
                confirmDeleteCourse()
            }
        }
        message:
        {
            Text("将删除「\(pendingDeleteCourse?.name ?? "该课程")」，此操作不可撤销。")
        }
    }

    @ViewBuilder
    private func courseCard(_ course: Course) -> some View
    {
        VStack(alignment: .leading, spacing: 6)
        {
            Text(course.name)
                .font(.title2)
                .fontWeight(.semibold)
                .lineLimit(2)
                .padding(.vertical,4)

            Label("周\(toWeekday(course.day)) 第\(course.start)-\(course.endPeriod)节",
                  systemImage: "clock")
                .font(.subheadline)

            Label(course.weeks ?? "未知周次", systemImage: "calendar")
                .font(.subheadline)

            Label(course.room ?? "未知教室",
                  systemImage: "location")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Label(course.teacher ?? "未知老师", systemImage: "person")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(courseColor(for: course).opacity(scheduleContentOpacity))
        )
        .opacity(0.8)
        .optionalLiquidGlass(enabled: enableLiquidGlassEffect,cornerRadius:24)
        
    }

    private func toWeekday(_ day: Int) -> String
    {
        switch day
        {
        case 1:
            return "一"
        case 2:
            return "二"
        case 3:
            return "三"
        case 4:
            return "四"
        case 5:
            return "五"
        case 6:
            return "六"
        case 7:
            return "日"
        default:
            return "未知"
        }
    }

    private func courseColor(for course: Course) -> Color
    {
        // 和 ScheduleView 保持一致：优先用户自定义颜色
        if let hex = course.customColorHex, let custom = Color(hex: hex)
        {
            return custom
        }

        // 和 ScheduleView 同一套调色板
        let colors: [Color] = [
            .blue, .green, .orange, .purple,
            .pink, .red, .yellow, .gray,
            .teal, .indigo, .cyan, .mint,
            .brown, Color(red: 0.5, green: 0.2, blue: 0.8),
            Color(red: 0.9, green: 0.3, blue: 0.5),
            Color(red: 0.2, green: 0.6, blue: 0.4),
            Color(red: 0.4, green: 0.7, blue: 0.9),
            Color(red: 0.7, green: 0.5, blue: 0.9),
            Color(red: 0.9, green: 0.6, blue: 0.4),
            Color(red: 0.5, green: 0.8, blue: 0.6),
            Color(red: 0.9, green: 0.5, blue: 0.6),
            Color(red: 0.6, green: 0.4, blue: 0.7),
            Color(red: 0.3, green: 0.5, blue: 0.7),
            Color(red: 0.8, green: 0.6, blue: 0.3),
            Color(red: 0.2, green: 0.3, blue: 0.5),
            Color(red: 0.3, green: 0.5, blue: 0.3),
            Color(red: 0.6, green: 0.3, blue: 0.2),
            Color(red: 0.5, green: 0.2, blue: 0.4),
            Color(red: 0.2, green: 0.5, blue: 0.5),
            Color(red: 0.5, green: 0.4, blue: 0.2),
            Color(red: 0.4, green: 0.2, blue: 0.5),
            Color(red: 0.6, green: 0.2, blue: 0.3),
        ]
        return colors[course.colorRandom % colors.count]
    }

    private func loadSavedCourses()
    {
        guard let data = UserDefaults.standard.data(forKey: "saved_courses")
        else
        {
            courses = []
            return
        }

        do
        {
            let decoded = try JSONDecoder().decode([Course].self, from: data)
            courses = decoded
            sortCoursesByNameAndTime()
        }
        catch
        {
            print("load saved_courses failed: \(error)")
            courses = []
        }
    }

    private func confirmDeleteCourse()
    {
        guard let course = pendingDeleteCourse else { return }
        courses.removeAll { $0.id == course.id }
        pendingDeleteCourse = nil
        saveCourses()
    }

    private func saveCourses()
    {
        do
        {
            let data = try JSONEncoder().encode(courses)
            UserDefaults.standard.set(data, forKey: "saved_courses")
        }
        catch
        {
            print("save saved_courses failed: \(error)")
        }
    }

    private func sortCoursesByNameAndTime()
    {
        courses.sort
        {
            let lhsInitial = nameInitialKey($0.name)
            let rhsInitial = nameInitialKey($1.name)
            if lhsInitial != rhsInitial { return lhsInitial < rhsInitial }

            let lhsName = normalizedName($0.name)
            let rhsName = normalizedName($1.name)
            if lhsName != rhsName { return lhsName < rhsName }

            if $0.day != $1.day { return $0.day < $1.day }
            return $0.start < $1.start
        }
    }

    // 把中文转拼音后取首字母；英文字母直接取首字母
    private func nameInitialKey(_ name: String) -> String
    {
        let normalized = normalizedName(name)
        guard let first = normalized.first else { return "#" }
        return String(first)
    }

    private func normalizedName(_ name: String) -> String
    {
        let mutable = NSMutableString(string: name) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
        return (mutable as String)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    private func loadBackgroundImage()
    {
        guard !backgroundImageFilename.isEmpty
        else
        {
            backgroundImage = nil
            return
        }
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(backgroundImageFilename)
        if let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data)
        {
            backgroundImage = image
        }
        else
        {
            backgroundImage = nil
        }
    }
}

#Preview
{
    AllScheduleSetting()
}
