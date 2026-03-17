//
//  CourseView.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/10.
//  Rewritten by lancang on 2026/3/18
//  全部在同一个 VStack 层级，全文件零 ZStack
//  课程卡片用 VStack + .background，不用 ZStack 叠层

import SwiftUI

let scheduleCellHeight: CGFloat = 58

struct AddCourseContext: Identifiable
{
    let id = UUID()
    let day: Int
    let period: Int
}

// MARK: - ScheduleView

struct ScheduleView: View
{
    @EnvironmentObject var userinfo: userInfo
    @State private var showSettings = false
    @State var nowDisplayMonth: Int = -1
    @State var nowMonth: Int = -1
    @State var today: Int = -1
    @State private var courses: [Course] = []
    @State var datesCurWeek: [Int] = [-1, -1, -1, -1, -1, -1, -1]
    @State var nowDisplayWeek: Int = -1

    @State private var inputWeek: String = ""
    @FocusState private var isWeekFieldFocused: Bool

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false

    @State private var showSaveSuccess = false

    @State private var addCourseContext: AddCourseContext?
    @State private var editCourseContext: Course?

    @State var semesterStartDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 2
        return Calendar.current.date(from: components) ?? Date()
    }()

    @AppStorage("semesterStartDateTimestamp") private var savedTimestamp: Double = 0
    @AppStorage("showBottomControls") private var showBottomControls: Bool = true

    let calendar = Calendar.current
    let minWeek = -9
    let maxWeek = 30

    private var weekBinding: Binding<String>
    {
        Binding(
            get: { inputWeek.isEmpty ? "\(nowDisplayWeek)" : inputWeek },
            set: { newValue in
                inputWeek = newValue.filter { "0123456789".contains($0) }
            }
        )
    }

    private func saveCourses()
    {
        do
        {
            let data = try JSONEncoder().encode(courses)
            UserDefaults.standard.set(data, forKey: "saved_courses")
            print("✅ 课程保存成功，共 \(courses.count) 门")
        }
        catch
        {
            print("❌ 课程保存失败: \(error)")
        }
    }

    var body: some View
    {
        NavigationStack
        {
            VStack(spacing: 0)
            {
                // 顶部月份 + 星期头
                HStack(spacing: 0)
                {
                    Text("\(nowDisplayMonth)月")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 60)
                        .padding(.vertical, 8)

                    WeekHeaderView(curMonth: $nowDisplayMonth, datesCurWeek: $datesCurWeek, today: $today, nowMonth: $nowMonth)
                }
                .background(Color(.secondarySystemBackground).opacity(0.5))
                .clipShape(Capsule())
                .padding(.horizontal, 10)
                .padding(.top, 10)

                // 课表主体 + 底部控制条（底部控制条浮在上面，这里的 ZStack 不是课表网格的，是页面布局的）
                pageBodyView
            }
            .toolbar
            {
                ToolbarItem(placement: .navigationBarLeading)
                {
                    HStack(spacing: 4)
                    {
                        Button(action: { showSettings = true })
                        { Image(systemName: "gearshape").fontWeight(.medium) }

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3))
                            { showBottomControls.toggle() }
                        })
                        {
                            Image(systemName: showBottomControls ? "chevron.down.circle" : "chevron.up.circle")
                                .fontWeight(.medium)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing)
                {
                    Button(action: {
                        exportScheduleAsImage(
                            courses: courses,
                            week: nowDisplayWeek,
                            datesCurWeek: datesCurWeek,
                            month: nowDisplayMonth
                        ) {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            showSaveSuccess = true
                        }
                    })
                    { Image(systemName: "square.and.arrow.down").fontWeight(.medium) }
                }
                ToolbarItem(placement: .navigationBarTrailing)
                {
                    Button(action: { addCourseContext = AddCourseContext(day: 1, period: 1) })
                    { Image(systemName: "plus.circle").fontWeight(.medium) }
                }
            }
            .sheet(isPresented: $showSettings)
            {
                ScheduleSettingView(semesterStartDate: $semesterStartDate, courses: $courses)
                    .environmentObject(userinfo)
            }
            .sheet(item: $editCourseContext)
            { course in
                if course.isManual
                { ManualCourseEditorView(courses: $courses, mode: .edit(course)) }
                else
                { Text("导入的课程不能编辑").presentationDetents([.height(200)]) }
            }
            .sheet(item: $addCourseContext)
            { context in
                ManualCourseEditorView(
                    courses: $courses,
                    mode: .add(prefillWeekday: context.day, prefillPeriod: context.period)
                )
            }
            .onAppear
            {
                loadSavedData()
                self.nowDisplayWeek = calculateCurrentWeek()
                updateDatesForDisplayWeek()
                self.today = getCurrentDate()
                self.nowMonth = getCurrentMonth()
            }
        }
        .alert("保存成功", isPresented: $showSaveSuccess)
        {
            Button("好的", role: .cancel) {}
        } message: {
            Text("已成功将本周课表保存到相册")
        }
    }

    // MARK: - 页面主体（ScrollView + 底部浮动控制条）

    @ViewBuilder
    private var pageBodyView: some View
    {
        ZStack(alignment: .bottom)
        {
            VStack
            {
                ScrollView
                {
                    HStack(alignment: .top, spacing: 0)
                    {
                        TimeScheduleView()
                            .frame(width: 60)
                            .background(Color(.secondarySystemBackground).opacity(0.5))
                            .clipShape(Capsule())

                        CourseGridView(
                            courses: courses,
                            nowdisplayWeek: nowDisplayWeek,
                            onDeleteCourse: { course in
                                if let index = courses.firstIndex(where: { $0.id == course.id })
                                {
                                    courses.remove(at: index)
                                    saveCourses()
                                }
                            },
                            onEditCourse: { course in
                                editCourseContext = course
                            },
                            onLongPressEmptyCell: { dayOfWeek, period in
                                addCourseContext = AddCourseContext(day: dayOfWeek, period: period)
                            },
                            onAddCourseFromCard: { course in
                                addCourseContext = AddCourseContext(day: course.day, period: course.start)
                            }
                        )
                    }
                    .padding(10)
                    .padding(.bottom, 140)
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            dragOffset = value.translation.width * 0.5
                        }
                        .onEnded { value in
                            let threshold: CGFloat = 30
                            if value.translation.width < -threshold
                            {
                                nowDisplayWeek = min(nowDisplayWeek + 1, maxWeek)
                                updateDatesForDisplayWeek()
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            }
                            else if value.translation.width > threshold
                            {
                                nowDisplayWeek = max(nowDisplayWeek - 1, minWeek)
                                updateDatesForDisplayWeek()
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            }
                            dragOffset = 0
                            isDragging = false
                        }
                )
            }

            if showBottomControls
            {
                bottomControlBar
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - 底部控制条

    @ViewBuilder
    private var bottomControlBar: some View
    {
        ZStack
        {
            HStack(spacing: 4)
            {
                Button(action: {
                    isWeekFieldFocused = false
                    inputWeek = ""
                    nowDisplayWeek -= 1
                    updateDatesForDisplayWeek()
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                })
                {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(nowDisplayWeek <= minWeek ? .gray : .blue)
                }
                .disabled(nowDisplayWeek <= minWeek)
                .optionalLiquidGlass()

                VStack(spacing: 4)
                {
                    if courses.isEmpty
                    {
                        Text("暂无课表")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    else
                    {
                        if nowDisplayWeek >= 1
                        {
                            HStack(spacing: 2)
                            {
                                Text("第")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)

                                TextField("", text: weekBinding)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 24, height: 16)
                                    .background(Color(.systemGray6))
                                    .clipShape(Capsule())
                                    .foregroundColor(.primary)
                                    .focused($isWeekFieldFocused)
                                    .textFieldStyle(.plain)
                                    .toolbar
                                    {
                                        ToolbarItemGroup(placement: .keyboard)
                                        {
                                            Spacer()
                                            Button("完成")
                                            {
                                                isWeekFieldFocused = false
                                                handleWeekJump()
                                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                            }
                                            .foregroundColor(.blue)
                                        }
                                    }
                                    .onTapGesture { inputWeek = "" }
                                    .onSubmit { handleWeekJump() }

                                Text("周")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                            }
                        }
                        else
                        {
                            Text("距离开学\n还有 \(-nowDisplayWeek + 1) 周")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }

                        if nowDisplayWeek == calculateCurrentWeek()
                        {
                            Text("本周")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
                .frame(width: 80)

                Button(action: {
                    isWeekFieldFocused = false
                    inputWeek = ""
                    nowDisplayWeek += 1
                    updateDatesForDisplayWeek()
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                })
                {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(nowDisplayWeek >= maxWeek ? .gray : .blue)
                }
                .disabled(nowDisplayWeek >= maxWeek)
                .optionalLiquidGlass()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .glassBackground(cornerRadius: 64)

            HStack
            {
                Spacer()
                VStack(spacing: 6)
                {
                    if nowDisplayWeek != calculateCurrentWeek()
                    {
                        Button(action: {
                            nowDisplayWeek = calculateCurrentWeek()
                            updateDatesForDisplayWeek()
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        })
                        {
                            Text("本周")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 28)
                                .background(Color.blue)
                                .clipShape(Capsule())
                        }
                        .optionalLiquidGlass()
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                    }

                    if nowDisplayWeek < 1
                    {
                        Button(action: {
                            nowDisplayWeek = 1
                            updateDatesForDisplayWeek()
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        })
                        {
                            Text("开学周")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 28)
                                .background(Color.green)
                                .clipShape(Capsule())
                        }
                        .optionalLiquidGlass()
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: nowDisplayWeek)
                .padding(.trailing, 16)
            }
        }
    }

    // MARK: - 工具方法

    private func handleWeekJump()
    {
        let target = Int(inputWeek) ?? nowDisplayWeek
        nowDisplayWeek = min(max(target, 1), 30)
        updateDatesForDisplayWeek()
        inputWeek = ""
    }

    func loadSavedData()
    {
        if savedTimestamp > 0 { semesterStartDate = Date(timeIntervalSince1970: savedTimestamp) }
        if let data = UserDefaults.standard.data(forKey: "saved_courses")
        {
            do {
                courses = try JSONDecoder().decode([Course].self, from: data)
                print("✅ 已加载 \(courses.count) 门课程")
            } catch {
                print("❌ 课表加载失败: \(error)")
                courses = []
            }
        }
        else { courses = [] }
    }

    func updateDatesForDisplayWeek()
    {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let startComps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: semesterStartDate)
        guard let firstMonday = cal.date(from: startComps) else { return }
        let offsetDays = (nowDisplayWeek - 1) * 7
        guard let targetMonday = cal.date(byAdding: .day, value: offsetDays, to: firstMonday) else { return }
        nowDisplayMonth = cal.component(.month, from: targetMonday)
        var newDates: [Int] = []
        for i in 0 ..< 7
        {
            if let date = cal.date(byAdding: .day, value: i, to: targetMonday)
            { newDates.append(cal.component(.day, from: date)) }
        }
        datesCurWeek = newDates
    }

    func getCurrentDate() -> Int { Calendar.current.component(.day, from: Date()) }
    func getCurrentMonth() -> Int { Calendar.current.component(.month, from: Date()) }

    func calculateCurrentWeek() -> Int
    {
        let cal = Calendar.current
        let startComps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: semesterStartDate)
        guard let startMonday = cal.date(from: startComps) else { return 1 }
        let nowComps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        guard let currentMonday = cal.date(from: nowComps) else { return 1 }
        let diff = cal.dateComponents([.weekOfYear], from: startMonday, to: currentMonday)
        return (diff.weekOfYear ?? 0) + 1
    }
}

// MARK: - WeekHeaderView

struct WeekHeaderView: View
{
    let weekDays = ["一", "二", "三", "四", "五", "六", "日"]
    @Binding var curMonth: Int
    @Binding var datesCurWeek: [Int]
    @Binding var today: Int
    @Binding var nowMonth: Int

    var body: some View
    {
        HStack(spacing: 0)
        {
            ForEach(0 ..< 7, id: \.self)
            { index in
                let isToday = curMonth == nowMonth && today == datesCurWeek[index]
                VStack(spacing: 4)
                {
                    Text(weekDays[index])
                        .font(.system(size: 13, weight: isToday ? .bold : .medium, design: .rounded))
                        .foregroundColor(isToday ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                    Text("\(datesCurWeek[index])")
                        .font(.system(size: 10, weight: isToday ? .bold : .regular, design: .rounded))
                        .foregroundColor(isToday ? .white : .secondary)
                }
                .padding(.vertical, 8)
                .background(isToday ? Capsule().fill(Color.blue) : Capsule().fill(Color.clear))
            }
        }
    }
}

// MARK: - CourseGridView
// 核心规则：
// 1. 每天一个 VStack，从第1节到第12节顺序渲染
// 2. 课程起始节次 → 渲染课程卡片(跨多节高度)，跳过后续被占节次
// 3. 空白节次 → 渲染空白格子
// 4. 所有元素在同一个 VStack 里，同一层级，无任何重叠
// 5. 课程卡片内部也不用 ZStack，用 .background 实现背景色

struct CourseGridView: View
{
    let courses: [Course]
    let nowdisplayWeek: Int

    var onDeleteCourse: ((Course) -> Void)?
    var onEditCourse: ((Course) -> Void)?
    var onLongPressEmptyCell: ((Int, Int) -> Void)?
    var onAddCourseFromCard: ((Course) -> Void)?

    private let weekdayNames = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View
    {
        HStack(spacing: 0)
        {
            ForEach(1 ... 7, id: \.self)
            { day in
                let dayCourses = coursesForDay(day)
                // ⚠️ 把 day 传进去，这样空白格子的 day 一定是正确的
                let slots = buildSlots(day: day, dayCourses: dayCourses)

                VStack(spacing: 0)
                {
                    ForEach(slots, id: \.id)
                    { slot in
                        switch slot.kind
                        {
                        case let .course(course):
                            courseCardView(course: course)

                        case let .empty(emptyDay, period):
                            emptyCellView(day: emptyDay, period: period)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Slot 数据结构

    struct RenderSlot: Identifiable
    {
        let id: String
        let kind: SlotKind
    }

    enum SlotKind
    {
        case course(Course)
        case empty(day: Int, period: Int)
    }

    private func coursesForDay(_ day: Int) -> [Course]
    {
        return courses.filter { $0.day == day && $0.parsedWeeks.contains(nowdisplayWeek) }
    }

    /// 从第1节到第12节顺序扫描，生成渲染列表
    /// day 参数从外层 ForEach 传入，保证空白格子的 day 永远正确
    private func buildSlots(day: Int, dayCourses: [Course]) -> [RenderSlot]
    {
        // 起始节次 -> 课程
        var startMap: [Int: Course] = [:]
        for course in dayCourses
        {
            startMap[course.start] = course
            print("📌 day\(day) 课程[\(course.name)] start=\(course.start) end=\(course.endPeriod) step=\(course.step)")
        }

        var slots: [RenderSlot] = []
        var period = 1

        while period <= 12
        {
            if let course = startMap[period]
            {
                print("🟢 day\(day) period=\(period) → 课程[\(course.name)]，跳到\(course.endPeriod + 1)")
                slots.append(RenderSlot(
                    id: "c_\(course.id)_\(period)",
                    kind: .course(course)
                ))
                period = course.endPeriod + 1
            }
            else
            {
                print("⬜ day\(day) period=\(period) → 空白")
                slots.append(RenderSlot(
                    id: "e_\(day)_\(period)",
                    kind: .empty(day: day, period: period)
                ))
                period += 1
            }
        }

        return slots
    }

    // MARK: - 空白格子（同一层级，单个 View，一个 contextMenu）

    @ViewBuilder
    private func emptyCellView(day: Int, period: Int) -> some View
    {
        Color(.systemGray6)
            .frame(height: scheduleCellHeight)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.gray.opacity(0.15), lineWidth: 0.5)
            )
            .padding(1)
            .contentShape(Rectangle())
            .contextMenu
            {
                Button
                {
                    print("🔵 空白长按 → 添加课程 day=\(day) period=\(period)")
                    onLongPressEmptyCell?(day, period)
                } label: {
                    Label("添加课程", systemImage: "plus.circle")
                }
            } preview: {
                VStack(spacing: 4)
                {
                    Image(systemName: "plus.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                    Text("周\(weekdayNames[day - 1]) 第\(period)节")
                        .font(.headline)
                }
                .padding(20)
                .onAppear {
                    print("📋 [上下文菜单打开] 空白格子 day=\(day) period=\(period)")
                }
            }
    }

    // MARK: - 课程卡片（同一层级，无 ZStack，用 .background 实现背景色）

    @ViewBuilder
    private func courseCardView(course: Course) -> some View
    {
        let spans = CGFloat(course.step)
        let cardHeight = spans * scheduleCellHeight + (spans - 1) * 2
        let color = courseColor(for: course)

        VStack(spacing: 4)
        {
            Spacer(minLength: 4)

            Text(course.name)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            if let location = course.room
            {
                VStack(spacing: 2)
                {
                    Image(systemName: "location.fill").font(.system(size: 8))
                    Text(location).font(.system(size: 10)).multilineTextAlignment(.center).lineLimit(2)
                }
                .foregroundColor(.white)
            }

            if let teacher = course.teacher
            {
                VStack(spacing: 2)
                {
                    Image(systemName: "person.fill").font(.system(size: 8))
                    Text(teacher)
                        .font(.system(size: teacher.count >= 3 ? 10 : 12))
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                }
                .foregroundColor(.white)
            }

            Spacer(minLength: 4)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .frame(height: cardHeight)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color)
                .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
        )
        .padding(1)
        .contentShape(Rectangle())
        .contextMenu
        {
            if course.isManual
            {
                Button
                {
                    print("🔵 课程长按 → 编辑 [\(course.name)]")
                    onEditCourse?(course)
                } label: {
                    Label("编辑", systemImage: "pencil")
                }
            }

            Button
            {
                print("🔵 课程长按 → 添加课程 day=\(course.day) period=\(course.start)")
                onAddCourseFromCard?(course)
            } label: {
                Label("添加课程", systemImage: "plus.circle")
            }

            Button(role: .destructive)
            {
                print("🔴 课程长按 → 删除 [\(course.name)]")
                onDeleteCourse?(course)
            } label: {
                Label("删除", systemImage: "trash")
            }
        } preview: {
            CourseCardPreview(course: course, week: nowdisplayWeek)
                .onAppear {
                    print("📋 [上下文菜单打开] 课程卡片 name=[\(course.name)] day=\(course.day) start=\(course.start) end=\(course.endPeriod) isManual=\(course.isManual) id=\(course.id)")
                }
        }
    }

    // MARK: - 课程颜色

    private func courseColor(for course: Course) -> Color
    {
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
}

// MARK: - 长按课程卡片预览

struct CourseCardPreview: View
{
    let course: Course
    let week: Int

    private let weekdays = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]

    var body: some View
    {
        HStack(spacing: 16)
        {
            VStack(alignment: .center, spacing: 6)
            {
                Text("第 \(week) 周")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                Text("第\(course.start)–\(course.endPeriod)节")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(weekdays[course.day - 1])
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .frame(width: 72)
            .padding(.vertical, 4)

            Rectangle()
                .fill(Color.secondary.opacity(0.25))
                .frame(width: 1)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8)
            {
                Text(course.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                if let room = course.room, !room.isEmpty
                {
                    Label(room, systemImage: "location.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                if let teacher = course.teacher, !teacher.isEmpty
                {
                    Label(teacher, systemImage: "person.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                if course.isManual
                {
                    Label("手动添加", systemImage: "hand.tap.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.blue.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(width: 320)
        .background(Color(.systemBackground))
    }
}

// MARK: - 时间轴

struct ClassPeriod: Identifiable
{
    let id: Int
    let periodNumber: Int
    let startTime: String
    let endTime: String
}

struct TimeScheduleView: View
{
    let classPeriods: [ClassPeriod] = [
        ClassPeriod(id: 1, periodNumber: 1, startTime: "8:00", endTime: "8:45"),
        ClassPeriod(id: 2, periodNumber: 2, startTime: "8:55", endTime: "9:40"),
        ClassPeriod(id: 3, periodNumber: 3, startTime: "10:00", endTime: "10:45"),
        ClassPeriod(id: 4, periodNumber: 4, startTime: "10:55", endTime: "11:40"),
        ClassPeriod(id: 5, periodNumber: 5, startTime: "14:30", endTime: "15:15"),
        ClassPeriod(id: 6, periodNumber: 6, startTime: "15:25", endTime: "16:10"),
        ClassPeriod(id: 7, periodNumber: 7, startTime: "16:30", endTime: "17:15"),
        ClassPeriod(id: 8, periodNumber: 8, startTime: "17:25", endTime: "18:10"),
        ClassPeriod(id: 9, periodNumber: 9, startTime: "19:00", endTime: "19:45"),
        ClassPeriod(id: 10, periodNumber: 10, startTime: "19:50", endTime: "20:35"),
        ClassPeriod(id: 11, periodNumber: 11, startTime: "20:40", endTime: "21:25"),
        ClassPeriod(id: 12, periodNumber: 12, startTime: "21:30", endTime: "22:15"),
    ]

    var body: some View
    {
        VStack(spacing: 0)
        {
            ForEach(classPeriods)
            { period in
                VStack(spacing: 2)
                {
                    Text("\(period.periodNumber)")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    Text(period.startTime)
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                    Text(period.endTime)
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(height: scheduleCellHeight)
                .padding(1)
            }
        }
    }
}

#Preview
{
    ScheduleView()
        .environmentObject(userInfo())
}
