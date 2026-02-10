//
//  CourseView.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/10.
//

import SwiftUI

struct ScheduleView: View
{
    @State private var showSettings = false
    @State var nowDisplayMonth: Int = -1 // 当前显示的星期
    @State var nowMonth: Int = -1 // 用户现在的星期
    @State var today: Int = -1 // 用户现在的日期
    @State private var courses: [Course] = testCourses // 使用测试数据
    @State var datesCurWeek: [Int] = [-1, -1, -1, -1, -1, -1, -1]

    @State var nowDisplayWeek: Int = -1 // 当前显示的周数
    // 在类或结构体里
    @State var semesterStartDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 2
        return Calendar.current.date(from: components) ?? Date()
    }() // 开学的日期

    let calendar = Calendar.current

    var body: some View
    {
        NavigationStack
        {
            VStack(spacing: 0)
            {
                // 顶部星期
                HStack(spacing: 0)
                {
                    // 左上角月份占位
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

                // 课程表主体
                ZStack(alignment: .bottom)
                {
                    VStack
                    {
                        ScrollView
                        {
                            HStack(alignment: .top, spacing: 0)
                            {
                                // 左侧时间
                                TimeScheduleView()
                                    .frame(width: 60)
                                    .background(Color(.secondarySystemBackground).opacity(0.5))
                                    .clipShape(Capsule())

                                // 右侧课程网格
                                CourseGridView(courses: courses, nowdisplayWeek: nowDisplayWeek)
                            }

                            .padding(10)
                        }
                    }

                    HStack(spacing: 20)
                    {
                        // 左箭头
                        Button(action: {
                            nowDisplayWeek -= 1
                            updateDatesForDisplayWeek()
                        })
                        {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 40))
                        }

                        // 周次显示卡片
                        VStack(spacing: 4)
                        {
                            if(nowDisplayWeek >= 1 )
                            {
                                Text("第 \(nowDisplayWeek) 周")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                            }
                            else
                            {
                                Text("距离开学\n还有 \(-nowDisplayWeek+1) 周")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
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
                        .frame(width: 80)

                        // 右箭头
                        Button(action: {
                            nowDisplayWeek += 1
                            updateDatesForDisplayWeek()
                        })
                        {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 40))
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(.regularMaterial) // 毛玻璃效果
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                    .padding(.bottom, 20) // 距离底部高度
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
                Text("设置页面")
            }
            .onAppear
            {
                    let currentWeek = calculateCurrentWeek()
                    self.nowDisplayWeek = currentWeek
                    
                    updateDatesForDisplayWeek()
                    
                    self.today = getCurrentDate()
                    self.nowMonth = getCurrentMonth()
            }
        }
    }

    func updateDatesForDisplayWeek()
    {
        var cal = Calendar.current
        cal.firstWeekday = 2 // 确保周一作为第一天

        // 找到开学日期的那一周的周一
        let startComps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: semesterStartDate)
        guard let firstMonday = cal.date(from: startComps) else { return }

        // 计算当前显示周的周一：开学周一 + (目标周数 - 1) * 7天
        let offsetDays = (nowDisplayWeek - 1) * 7
        guard let targetMonday = cal.date(byAdding: .day, value: offsetDays, to: firstMonday) else { return }

        // 更新月份显示
        nowDisplayMonth = cal.component(.month, from: targetMonday)

        // 更新数组
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

    func getDaysInCurrentWeek() -> [Int]
    {
        var calendar = Calendar.current
        calendar.firstWeekday = 2

        let now = Date()

        // 找到本周的起始点
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))
        else
        {
            return []
        }

        // 循环获取 7 天的日期数字
        return (0 ..< 7).compactMap
        { day -> Int? in
            if let date = calendar.date(byAdding: .day, value: day, to: startOfWeek)
            {
                return calendar.component(.day, from: date)
            }
            return nil
        }
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
        // 1. 规范化：找到开学日期那一周的周一 00:00:00
        let startComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: semesterStartDate)
        guard let startMonday = calendar.date(from: startComponents) else { return 1 }

        // 2. 规范化：找到今天（或者你想对比的日期）的周一 00:00:00
        let now = Date()
        let nowComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        guard let currentMonday = calendar.date(from: nowComponents) else { return 1 }

        // 3. 计算周数差
        let components = calendar.dateComponents([.weekOfYear], from: startMonday, to: currentMonday)
        let weekDiff = components.weekOfYear ?? 0

        // 开学那一周周差为 0，所以是第 1 周
        return weekDiff + 1
    }
}

struct WeekHeaderView: View
{
    let weekDays = ["一", "二", "三", "四", "五", "六", "日"]
    @Binding var curMonth: Int // 当前显示的月份
    @Binding var datesCurWeek: [Int] // 当前显示的一周的天数
    @Binding var today: Int // 用户当前天
    @Binding var nowMonth: Int // 用户当前月份

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
                        ? Capsule().fill(Color.blue) // 🌟 今天的背景是蓝色胶囊
                        : Capsule().fill(Color.clear) // 平时透明
                )
            }
        }
    }
}

// 课程表
struct CourseGridView: View
{
    let courses: [Course]
    let nowdisplayWeek: Int // 当前显示的周数

    var body: some View
    {
        HStack(spacing: 0)
        {
            // 7天
            ForEach(1 ... 7, id: \.self)
            { dayOfWeek in
                ZStack(alignment: .top)
                {
                    // 背景网格
                    VStack(spacing: 0)
                    {
                        ForEach(1 ... 12, id: \.self)
                        { _ in
                            EmptyCell()
                        }
                    }

                    // 课程卡片层
                    VStack(spacing: 0)
                    {
                        ForEach(1 ... 12, id: \.self)
                        { period in
                            if let course = getCourse(for: dayOfWeek, period: period)
                            {
                                if isCourseDisplayNowWeek(course: course, week: nowdisplayWeek)
                                {
                                    if isFirstPeriod(course: course, period: period)
                                    {
                                        // 只在第一节显示合并的课程卡片
                                        MergedCourseCard(course: course)
                                    }
                                }
                            }
                            else
                            {
                                // 无课程：透明占位
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

    // 是否为第一节课
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

    // 根据星期和节次查找课程
    private func getCourse(for dayOfWeek: Int, period: Int) -> Course?
    {
        for course in courses
        {
            // 检查星期
            guard Int(course.xqj) == dayOfWeek
            else
            {
                continue
            }

            // 解析节次
            let jcsParts = course.jcs.split(separator: "-")
            if jcsParts.count == 2,
               let startjcs = Int(jcsParts[0]),
               let endjcs = Int(jcsParts[1])
            {
                if period >= startjcs && period <= endjcs
                {
                    return course
                }
            }
        }
        return nil
    }

    // 本周是否有课
    private func isCourseDisplayNowWeek(course: Course, week: Int) -> Bool
    {
        return course.parsedWeeks.contains(week)
    }
}

// 课程卡片
struct MergedCourseCard: View
{
    let course: Course
    private let cellHeight: CGFloat = 70
    private let cellPadding: CGFloat = 1

    var body: some View
    {
        ZStack
        {
            // 背景
            RoundedRectangle(cornerRadius: 12)
                .fill(courseColor)
                .shadow(color: courseColor.opacity(0.3), radius: 4, x: 0, y: 2)

            // 课程信息
            VStack(spacing: 8)
            {
                // 课程名称
                Text(course.kcmc)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                // 教室
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

                // 教师
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

    // 课程跨越的节数
    private var courseSpans: Int
    {
        let jcsParts = course.jcs.split(separator: "-")
        guard jcsParts.count == 2,
              let start = Int(jcsParts[0]),
              let end = Int(jcsParts[1])
        else { return 1 }
        return end - start + 1
    }

    // 总高度 = 节数 × (单元格高度 + padding × 2)
    private var totalHeight: CGFloat
    {
        let spans = CGFloat(courseSpans)
        return spans * cellHeight + (spans - 1) * cellPadding * 2
    }

    // 课程颜色
    private var courseColor: Color
    {
        let colors: [Color] = [
            .blue, .green, .orange, .purple, .pink,
            .teal, .indigo, .cyan, .mint, .brown,
        ]
        let hash = abs(course.jxb_id.hashValue)
        return colors[hash % colors.count]
    }
}

// 空格子
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

// 课程时间段
struct ClassPeriod: Identifiable
{
    let id: Int
    let periodNumber: Int
    let startTime: String
    let endTime: String
}

// 时间表视图
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

// 单个时间段视图
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
}

var testCourses: [Course]
{
    [
        Course(
            jxb_id: "TEST_001_HPC",
            kch_id: "C001",
            kcmc: "高性能计算",
            xqj: "1",
            jcs: "5-8",
            cdmc: "逸夫楼C302",
            xm: "郑芳",
            zcmc: "副教授",
            jxbzc: "计科2301;计科2302;计科2303",
            zcd: "4-5周,7-8周",
            xqjmc: "星期一"
        ),

        Course(
            jxb_id: "TEST_002_COMPILER",
            kch_id: "C002",
            kcmc: "编译原理",
            xqj: "2",
            jcs: "3-4",
            cdmc: "四教A410",
            xm: "刘善梅",
            zcmc: "副教授",
            jxbzc: "计科2301;计科2302",
            zcd: "1-9周",
            xqjmc: "星期二"
        ),

        Course(
            jxb_id: "TEST_003_IOT",
            kch_id: "C003",
            kcmc: "物联网工程",
            xqj: "3",
            jcs: "9-10",
            cdmc: "三教B101",
            xm: "朱容波",
            zcmc: "教授",
            jxbzc: "计科2301;计科2302;计科2303;计科2304",
            zcd: "3-10周",
            xqjmc: "星期三"
        ),
    ]
}
