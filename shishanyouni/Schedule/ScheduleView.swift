//
//  CourseView.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/10.
//  updated by lancang on 2026/3/15

import SwiftUI

let scheduleCellHeight: CGFloat = 58 // 全局课表单元格高度

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
    // 新增
    @State private var showAddCourse = false
    @State private var selectedCourse: Course?
    @State private var showEditCourse = false

    @State private var inputWeek: String = ""
    @FocusState private var isWeekFieldFocused: Bool

    // 滑动手势相关
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false

    // 保存本周课表为图片
    @State private var showSaveSuccess = false
    @State private var longPressedCell: (day: Int,period: Int)?

    @State var semesterStartDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 2
        return Calendar.current.date(from: components) ?? Date()
    }()

    @AppStorage("semesterStartDateTimestamp") private var savedTimestamp: Double = 0

    let calendar = Calendar.current
    let minWeek = -9 // 最多能滑到开学前10周
    let maxWeek = 30 // 最多30周

    private var weekBinding: Binding<String>
    {
        Binding(
            get: {
                // 如果 inputWeek 有值（用户正在输入），显示输入的
                // 否则显示当前显示的周数
                inputWeek.isEmpty ? "\(nowDisplayWeek)" : inputWeek
            },
            set: { newValue in
                // 只允许输入数字
                let filtered = newValue.filter { "0123456789".contains($0) }
                inputWeek = filtered
            }
        )
    }

    // 保存函数
    private func saveCourses()
    {
        do
        {
            let encoder = JSONEncoder()
            let data = try encoder.encode(courses)
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
                                // 修改
                                // 修改这一部分
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
                                        selectedCourse = course
                                        showEditCourse = true
                                    },
                                    // 新增：长按空白单元格回调
                                    onLongPressEmptyCell: { dayOfWeek, period in
                                        // 创建预填充的课程数据
                                        let newCourse = Course.createManualCourse(
                                            name: "",
                                            weekday: dayOfWeek,
                                            startPeriod: period,
                                            endPeriod: period + 1, // 默认2节课
                                            weeks: [nowDisplayWeek], // 默认当前周
                                            location: nil,
                                            teacher: nil
                                        )
                                        selectedCourse = newCourse
                                        showAddCourse = true
                                    }
                                )
                            }
                            .padding(10)
                            .padding(.bottom, 140)
                        }
                        .gesture(
                            DragGesture()
                                .onChanged
                                { value in
                                    isDragging = true
                                    dragOffset = value.translation.width * 0.5 // 减缓拖动速度
                                }
                                .onEnded
                                { value in
                                    let threshold: CGFloat = 30 // 滑动阈值

                                    if value.translation.width < -threshold
                                    {
                                        // 向左滑动 - 下一周
                                        nowDisplayWeek = min(nowDisplayWeek + 1, maxWeek)
                                        updateDatesForDisplayWeek()
                                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                                    }
                                    else if value.translation.width > threshold
                                    {
                                        // 向右滑动 - 上一周
                                        nowDisplayWeek = max(nowDisplayWeek - 1, minWeek)
                                        updateDatesForDisplayWeek()
                                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                                    }

                                    dragOffset = 0

                                    isDragging = false
                                }
                        )
                    }

                    VStack(spacing: 12)
                    {
                        HStack(spacing: 12)
                        {
                            if nowDisplayWeek != calculateCurrentWeek()
                            {
                                Button(action: {
                                    nowDisplayWeek = calculateCurrentWeek()
                                    updateDatesForDisplayWeek()
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                })
                                {
                                    Text("跳转至本周")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.blue)
                                        .clipShape(Capsule())
                                }

                                .optionalLiquidGlass()
                            }

                            if nowDisplayWeek < 1
                            {
                                Button(action: {
                                    nowDisplayWeek = 1
                                    updateDatesForDisplayWeek()
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                })
                                {
                                    if !courses.isEmpty
                                    {
                                        Text("跳转至开学周")
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.green)
                                            .clipShape(Capsule())
                                    }
                                }
                                .optionalLiquidGlass()
                            }
                        }
                        .opacity(nowDisplayWeek != calculateCurrentWeek() || nowDisplayWeek < 1 ? 1 : 0)
                        .frame(height: nowDisplayWeek != calculateCurrentWeek() || nowDisplayWeek < 1 ? nil : 0)
                        .animation(.easeInOut(duration: 0.3), value: nowDisplayWeek)
                        .opacity(nowDisplayWeek != calculateCurrentWeek() || nowDisplayWeek < 1 ? 1 : 0)
                        .frame(height: nowDisplayWeek != calculateCurrentWeek() || nowDisplayWeek < 1 ? nil : 0)

                        HStack(spacing: 20)
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
                                    .font(.system(size: 40))
                                    .foregroundColor(nowDisplayWeek <= minWeek ? .gray : .blue)
                            }
                            .disabled(nowDisplayWeek <= minWeek)
                            .optionalLiquidGlass()

                            VStack(spacing: 4)
                            {
                                if courses.isEmpty
                                {
                                    Text("暂无课表")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
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

                                            // 绑定到 weekBinding，去掉 prompt
                                            TextField("", text: weekBinding)
                                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                                .keyboardType(.numberPad)
                                                .multilineTextAlignment(.center)
                                                .frame(width: 36, height: 28)
                                                .background(Color(.systemGray6))
                                                .clipShape(Capsule())
                                                .foregroundColor(.primary)
                                                .focused($isWeekFieldFocused)
                                                .textFieldStyle(.plain)
                                                .toolbar {
                                                    ToolbarItemGroup(placement: .keyboard) {
                                                        Spacer()
                                                        Button("完成") {
                                                            isWeekFieldFocused = false
                                                            handleWeekJump()
                                                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                                                        }
                                                        .foregroundColor(.blue)
                                                    }
                                                }
                                                .onTapGesture {
                                                    inputWeek = ""
                                                }
                                                .onSubmit {
                                                    handleWeekJump()
                                                }


                                            Text("周")
                                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                                .foregroundColor(.primary)
                                        }
                                    }
                                    else
                                    {
                                        if nowDisplayWeek == calculateCurrentWeek()
                                        {
                                            Text("距离开学\n还有 \(-nowDisplayWeek + 1) 周")
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                        }
                                        else
                                        {
                                            Text("距离开学\n还有 \(-nowDisplayWeek + 1) 周")
                                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                        }
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
                                    .font(.system(size: 40))
                                    .foregroundColor(nowDisplayWeek >= maxWeek ? .gray : .blue)
                            }
                            .disabled(nowDisplayWeek >= maxWeek)
                            .optionalLiquidGlass()
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .glassBackground(cornerRadius: 64)
                    }
                    .padding(.bottom, 20)
                }
            }
            .toolbar
            {
                ToolbarItem(placement: .navigationBarLeading)
                {
                    Button(action: {
                        showSettings = true
                    })
                    {
                        Image(systemName: "gearshape")
                            .fontWeight(.medium)
                    }
                }
                // 保存到相册
                ToolbarItem(placement: .navigationBarTrailing)
                {
                    Button(action: {
                        exportScheduleAsImage(
                            courses: courses,
                            week: nowDisplayWeek,
                            datesCurWeek: datesCurWeek,
                            month: nowDisplayMonth
                        )
                        {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            showSaveSuccess = true
                        }
                    })
                    {
                        Image(systemName: "square.and.arrow.down")
                            .fontWeight(.medium)
                    }
                }
                // 新增：手动添加课程按钮
//                ToolbarItem(placement: .navigationBarTrailing)
//                {
//                    Button(action: {
//                        showAddCourse = true
//                    })
//                    {
//                        Image(systemName: "plus.circle")
//                            .fontWeight(.medium)
//                    }
//                }
            }
            .sheet(isPresented: $showSettings)
            {
                ScheduleSettingView(
                    semesterStartDate: $semesterStartDate,
                    courses: $courses
                )
                .environmentObject(userinfo)
            }
            .sheet(isPresented: $showEditCourse)
            {
                if let course = selectedCourse
                {
                    if course.isManual
                    {
                        ManualCourseEditorView(courses: $courses, mode: .edit(course))
                    }
                    else
                    {
                        // 如果是导入的课程，显示提示
                        Text("导入的课程不能编辑")
                            .presentationDetents([.height(200)])
                    }
                }
            }
            // 新增：手动添加课程的 sheet
            // 修改这一部分
            .sheet(isPresented: $showAddCourse)
            {
                if let course = selectedCourse, course.name.isEmpty {
                    // 如果是长按空白单元格创建的预填充课程，传递编辑模式
                    ManualCourseEditorView(courses: $courses, mode: .edit(course))
                } else {
                    // 正常的添加模式
                    ManualCourseEditorView(courses: $courses, mode: .add)
                }
            }
            .onAppear
            {
                loadSavedData()

                let currentWeek = calculateCurrentWeek()
                self.nowDisplayWeek = currentWeek
                updateDatesForDisplayWeek()
                self.today = getCurrentDate()
                self.nowMonth = getCurrentMonth()
            }
        }
        .alert("保存成功", isPresented: $showSaveSuccess)
        {
            Button("好的", role: .cancel) { }
        } message: {
            Text("已成功将本周课表保存到相册")
        }
    }

    private func handleWeekJump()
    {
        // 尝试将输入转为数字，如果为空则默认使用当前周
        let target = Int(inputWeek) ?? nowDisplayWeek

        // 限制范围1到20周
        let minWeek = 1
        let maxWeek = 30

        // closed range 限制数值
        let clampedWeek = min(max(target, minWeek), maxWeek)

        // 更新
        nowDisplayWeek = clampedWeek
        updateDatesForDisplayWeek()

        inputWeek = ""
    }

    // 加载保存的数据
    func loadSavedData()
    {
        // 加载开学日期
        if savedTimestamp > 0
        {
            semesterStartDate = Date(timeIntervalSince1970: savedTimestamp)
            print("✅ 已加载开学日期: \(semesterStartDate)")
        }

        // 加载课表
        if let data = UserDefaults.standard.data(forKey: "saved_courses")
        {
            do
            {
                let decoder = JSONDecoder()
                courses = try decoder.decode([Course].self, from: data)
                print("✅ 已加载 \(courses.count) 门课程")
            }
            catch
            {
                print("❌ 课表加载失败: \(error)")
                courses = []
            }
        }
        else
        {
            print("ℹ️ 没有保存的课表,使用空课表")
            courses = []
        }
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
            {
                newDates.append(cal.component(.day, from: date))
            }
        }
        datesCurWeek = newDates
    }

    func getCurrentDate() -> Int
    {
        let now = Date()
        let calendar = Calendar.current
        let day = calendar.component(.day, from: now)
        return day
    }

    func getCurrentMonth() -> Int
    {
        let now = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: now)
        return month
    }

    func calculateCurrentWeek() -> Int
    {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: semesterStartDate)
        guard let startMonday = calendar.date(from: startComponents) else { return 1 }

        let now = Date()
        let nowComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        guard let currentMonday = calendar.date(from: nowComponents) else { return 1 }

        let components = calendar.dateComponents([.weekOfYear], from: startMonday, to: currentMonday)
        let weekDiff = components.weekOfYear ?? 0

        return weekDiff + 1
    }
}

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
                VStack(spacing: 4)
                {
                    if curMonth == nowMonth && today == datesCurWeek[index]
                    {
                        Text(weekDays[index])
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)

                        Text("\(datesCurWeek[index])")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    else
                    {
                        Text(weekDays[index])
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                        Text("\(datesCurWeek[index])")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
                .background(
                    curMonth == nowMonth && today == datesCurWeek[index]
                        ? Capsule().fill(Color.blue)
                        : Capsule().fill(Color.clear)
                )
            }
        }
    }
}

struct CourseGridView: View
{
    let courses: [Course]
    let nowdisplayWeek: Int

    var onDeleteCourse: ((Course) -> Void)?
    var onEditCourse: ((Course) -> Void)?
    // 新增：长按空白单元格添加课程的回调
    var onLongPressEmptyCell: ((Int, Int) -> Void)? // (dayOfWeek, period)

    var body: some View
    {
        HStack(spacing: 0)
        {
            ForEach(1 ... 7, id: \.self)
            { dayOfWeek in
                ZStack(alignment: .top)
                {
                    VStack(spacing: 0)
                    {
                        ForEach(1 ... 12, id: \.self)
                        { period in
                            EmptyCell()
                                // 新增：为空白单元格添加长按手势
                                .onLongPressGesture(minimumDuration: 0.5) {
                                    onLongPressEmptyCell?(dayOfWeek, period)
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                }
                        }
                    }

                    VStack(spacing: 0)
                    {
                        ForEach(1 ... 12, id: \.self)
                        { period in
                            if let course = getCourse(for: dayOfWeek, period: period, week: nowdisplayWeek)
                            {
                                if isFirstPeriod(course: course, period: period)
                                {
                                    MergedCourseCard(
                                        course: course,
                                        onDelete: { onDeleteCourse?(course) },
                                        onEdit: { onEditCourse?(course) })
                                }
                            }
                            else
                            {
                                Color.clear
                                    .frame(height: scheduleCellHeight)
                                    .padding(1)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func isFirstPeriod(course: Course, period: Int) -> Bool
    {
        return period == course.start
    }

    private func getCourse(for dayOfWeek: Int, period: Int, week: Int) -> Course?
    {
        for course in courses
        {
            guard course.day == dayOfWeek else { continue }

            if period >= course.start && period <= course.endPeriod && course.parsedWeeks.contains(week)
            {
                return course
            }
        }
        return nil
    }

    private func isCourseDisplayNowWeek(course: Course, week: Int) -> Bool
    {
        return course.parsedWeeks.contains(week)
    }
}
struct MergedCourseCard: View
{
    let course: Course

    //  新增
    var onDelete: (() -> Void)?
    var onEdit: (() -> Void)?

    private let cellHeight: CGFloat = scheduleCellHeight
    private let cellPadding: CGFloat = 1

    var body: some View
    {
        ZStack
        {
            RoundedRectangle(cornerRadius: 12)
                .fill(courseColor)
                .shadow(color: courseColor.opacity(0.3), radius: 4, x: 0, y: 2)

            VStack(spacing: 8)
            {
                Text(course.name)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                if let location = course.room
                {
                    VStack(spacing: 4)
                    {
                        Image(systemName: "location.fill")
                            .font(.system(size: 8))
                        Text(location)
                            .font(.system(size: 10))
                            .multilineTextAlignment(.center)
                    }
                    .foregroundColor(.white)
                }

                if let teacher = course.teacher
                {
                    VStack(spacing: 4)
                    {
                        Image(systemName: "person.fill")
                            .font(.system(size: 8))
                        Text(teacher)
                            .font(.system(size: teacher.count >= 3 ? 10 : 12))
                            .multilineTextAlignment(.center)
                    }
                    .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        // add
        .contextMenu
        {
            if course.isManual
            {
//                Button(action: { onEdit?() })
//                {
//                    Label("编辑", systemImage: "pencil")
//                }

                Button(role: .destructive, action: { onDelete?() })
                {
                    Label("删除", systemImage: "trash")
                }
            }
        }

        .frame(height: totalHeight)
        .padding(1)
    }

    private var courseSpans: Int
    {
        course.step
    }

    private var totalHeight: CGFloat
    {
        let spans = CGFloat(courseSpans)
        return spans * cellHeight + (spans - 1) * cellPadding * 2
    }

    private var courseColor: Color
    {
        // 32种精心挑选的颜色，确保足够区分且视觉友好
        let colors: [Color] = [
            // 第一组：基础色系 (8种)
            .blue, .green, .orange, .purple,
            .pink, .red, .yellow, .gray,

            // 第二组：现代色系 (8种)
            .teal, .indigo, .cyan, .mint,
            .brown, Color(red: 0.5, green: 0.2, blue: 0.8), // 深紫
            Color(red: 0.9, green: 0.3, blue: 0.5), // 玫红
            Color(red: 0.2, green: 0.6, blue: 0.4), // 青绿

            // 第三组：柔和色系 (8种)
            Color(red: 0.4, green: 0.7, blue: 0.9), // 浅蓝
            Color(red: 0.7, green: 0.5, blue: 0.9), // 淡紫
            Color(red: 0.9, green: 0.6, blue: 0.4), // 浅橙
            Color(red: 0.5, green: 0.8, blue: 0.6), // 薄荷绿
            Color(red: 0.9, green: 0.5, blue: 0.6), // 珊瑚粉
            Color(red: 0.6, green: 0.4, blue: 0.7), // 薰衣草
            Color(red: 0.3, green: 0.5, blue: 0.7), // 钢蓝
            Color(red: 0.8, green: 0.6, blue: 0.3), // 金黄

            // 第四组：深色系 (8种)
            Color(red: 0.2, green: 0.3, blue: 0.5), // 深蓝
            Color(red: 0.3, green: 0.5, blue: 0.3), // 深绿
            Color(red: 0.6, green: 0.3, blue: 0.2), // 深棕
            Color(red: 0.5, green: 0.2, blue: 0.4), // 深紫红
            Color(red: 0.2, green: 0.5, blue: 0.5), // 深青
            Color(red: 0.5, green: 0.4, blue: 0.2), // 橄榄
            Color(red: 0.4, green: 0.2, blue: 0.5), // 茄紫
            Color(red: 0.6, green: 0.2, blue: 0.3), // 酒红
        ]
        let index = course.colorRandom
        return colors[index % colors.count]
    }
}

struct EmptyCell: View
{
    var body: some View
    {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(Color.gray.opacity(0.15), lineWidth: 0.5)
            .background(Color(.systemGray6))
            .frame(height: scheduleCellHeight)
            .padding(1)
            .cornerRadius(12)
    }
}

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
                TimeSlotView(period: period)
                    .padding(1)
            }
        }
    }
}

struct TimeSlotView: View
{
    let period: ClassPeriod
    private let cellHeight: CGFloat = scheduleCellHeight

    var body: some View
    {
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
        .frame(height: cellHeight)
    }
}

#Preview
{
    ScheduleView()
        .environmentObject(userInfo())
}
