//
//  CourseView.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/10.
//

import SwiftUI

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

    // 滑动手势相关
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false

    @State var semesterStartDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 2
        return Calendar.current.date(from: components) ?? Date()
    }()

    @AppStorage("semesterStartDateTimestamp") private var savedTimestamp: Double = 0

    let calendar = Calendar.current

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

                                CourseGridView(courses: courses, nowdisplayWeek: nowDisplayWeek)
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
                                        nowDisplayWeek += 1
                                        updateDatesForDisplayWeek()
                                    }
                                    else if value.translation.width > threshold
                                    {
                                        // 向右滑动 - 上一周
                                        nowDisplayWeek -= 1
                                        updateDatesForDisplayWeek()
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

                            })
                            {
                                Image(systemName: "chevron.left.circle.fill")
                                    .font(.system(size: 40))
                            }
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
                                                .focused($isWeekFieldFocused) // 绑定焦点
                                                .onTapGesture
                                                {
                                                    inputWeek = ""
                                                }
                                                .onSubmit
                                                {
                                                    handleWeekJump()
                                                }
                                                .toolbar
                                                {
                                                    ToolbarItemGroup(placement: .keyboard)
                                                    {
                                                        Spacer()
                                                        Button("完成")
                                                        {
                                                            handleWeekJump()
                                                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                                        }
                                                        .fontWeight(.bold)
                                                        .optionalLiquidGlass()
                                                    }
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

                            })
                            {
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.system(size: 40))
                            }
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
            }
            .sheet(isPresented: $showSettings)
            {
                ScheduleSettingView(
                    semesterStartDate: $semesterStartDate,
                    courses: $courses
                )
                .environmentObject(userinfo)
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
                        { _ in
                            EmptyCell()
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
                                    MergedCourseCard(course: course)
                                }
                            }
                            else
                            {
                                Color.clear
                                    .frame(height: 70)
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
        let jcsParts = course.jcs.split(separator: "-")
        guard let startPeriod = Int(jcsParts[0]) else { return false }
        if period == startPeriod
        {
            return true
        }
        return false
    }

    private func getCourse(for dayOfWeek: Int, period: Int, week: Int) -> Course?
    {
        for course in courses
        {
            guard Int(course.xqj) == dayOfWeek
            else
            {
                continue
            }

            let jcsParts = course.jcs.split(separator: "-")
            if jcsParts.count == 2,
               let startjcs = Int(jcsParts[0]),
               let endjcs = Int(jcsParts[1])
            {
                // 必须同时满足：节次匹配 AND 周次匹配
                if period >= startjcs && period <= endjcs && course.parsedWeeks.contains(week)
                {
                    return course
                }
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
    private let cellHeight: CGFloat = 70
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
                Text(course.kcmc)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                if let location = course.cdmc
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

                if let teacher = course.xm
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
        .frame(height: totalHeight)
        .padding(1)
    }

    private var courseSpans: Int
    {
        let jcsParts = course.jcs.split(separator: "-")
        guard jcsParts.count == 2,
              let start = Int(jcsParts[0]),
              let end = Int(jcsParts[1])
        else { return 1 }
        return end - start + 1
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
        let index = course.colorIndex ?? 0
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
            .frame(height: 70)
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
    private let cellHeight: CGFloat = 70

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
