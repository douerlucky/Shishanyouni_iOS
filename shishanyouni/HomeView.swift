import SwiftUI

struct HomeView: View
{
    @State private var cookieInput = "No cookies yet."

    // 控制页面跳转状态
    @State private var navigateToGrades = false
    @State private var navigateDebugRoom = false
    @State private var navigateToExams = false
    @State private var navigateToNanhuRun = false
    @State private var navigateToPhysicalTest = false
    @State private var navigateToAllCoueseSearch = false
    @State private var navigateToSchoolCalender = false
    @State private var navigateToBus = false
    @State private var navigateElectricity = false
    @State private var navigateToClassroom = false
    @State private var navigateToEvents = false
    @State private var navigateToStrategy = false
    @State private var navigateToClub = false

    @State private var currentTime = Date() // 储存当前时间
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect() // 创建一个定时器

    var timeString: String
    {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss" // 显示 几点:几分:几秒
        return formatter.string(from: currentTime)
    }

    var dateAndWeekString: String
    {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: currentTime)
    }

    @State private var date: String = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d" // 只要日期数字
        return formatter.string(from: Date())
    }()

    @EnvironmentObject var userinfo: userInfo

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    var body: some View
    {
        NavigationStack
        {
            ScrollView
            {
                VStack(alignment: .leading, spacing: 8)
                {
                    HStack(alignment: .center) // 1. 让左边的 Stack 和右边的 Text 垂直居中对齐
                    {
                        if userinfo.showClock
                        {
                            VStack(alignment: .leading, spacing: 2) // 2. 关键：设置左对齐，并稍微缩减行间距
                            {
                                Text(dateAndWeekString)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)

                                Text(timeString)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .monospacedDigit() // 加上这个，数字跳动会更稳
                            }
                            .onReceive(timer)
                            { input in
                                currentTime = input
                            }
                        }

                        Spacer() // 4. 加个弹簧，把随机话语顶到最右边（如果你喜欢左右分布的话）

                        if userinfo.showDailyMessage
                        {
                            Text(userinfo.sessionDailyMessage)
                                .font(.system(size: 16, weight: .medium))
                                .multilineTextAlignment(.trailing) // 如果话语太长换行，也保持右对齐
                                .frame(maxWidth: 300, alignment: .trailing) // 限制宽度，防止把左边的时钟挤扁了
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)

                    if let days = userinfo.daysSinceEnrollment
                    {
                        if userinfo.showEnrollmentDays
                        {
                            VStack(alignment: .leading, spacing: 4)
                            {
                                Text("今天是在华农的第 \(days) 天")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        }
                    }
                    else
                    {
                        // 未登录或学号不符时的占位
                        Text("欢迎使用狮山有你，快去登录吧")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    }
                }
                LazyVGrid(columns: columns, spacing: 20)
                {
//                    MenuGridItem(title: "Debug页面", icon: "ladybug.fill", color: .orange)
//                    {
//                        navigateDebugRoom = true
//                    }

                    MenuGridItem(title: "成绩查询", icon: "graduationcap.fill", color: .blue)
                    {
                        navigateToGrades = true
                    }

                    MenuGridItem(title: "考试查询", icon: "pencil.line", color: .green)
                    {
                        navigateToExams = true
                    }

                    MenuGridItem(title: "全校课程查询", icon: "mail.and.text.magnifyingglass", color: .yellow)
                    {
                        navigateToAllCoueseSearch = true
                    }
                    MenuGridItem(title: "空教室查询", icon: "door.left.hand.open", color: .purple)
                    {
                        navigateToClassroom = true
                    }

                    MenuGridItem(title: "环湖跑查询", icon: "figure.run", color: .brown)
                    {
                        navigateToNanhuRun = true
                    }

                    MenuGridItem(title: "体测查询", icon: "figure.run.square.stack.fill", color: .red)
                    {
                        navigateToPhysicalTest = true
                    }
                    MenuGridItem(title: "宿舍电费", icon: "gauge.with.needle.fill", color: .indigo)
                    {
                        navigateElectricity = true
                    }
                    if #available(iOS 26.0, *)
                    {
                        MenuGridItem(title: "校历查询", icon: date + ".calendar", color: .cyan)
                        {
                            navigateToSchoolCalender = true
                        }
                    }
                    else
                    {
                        MenuGridItem(title: "校历查询", icon: "calendar", color: .cyan)
                        {
                            navigateToSchoolCalender = true
                        }
                    }
                    MenuGridItem(title: "校车查询", icon: "bus", color: .pink)
                    {
                        navigateToBus = true
                    }
                    MenuGridItem(title: "攻略", icon: "info.bubble", color: .teal)
                    {
                        navigateToStrategy = true
                    }
                    MenuGridItem(title: "社团", icon: "person.2.fill", color: .gray)
                    {
                        navigateToClub = true
                    }

//                    MenuGridItem(title: "每日日程", icon: "calendar.day.timeline.left", color: .purple)
//                    {
//                        navigateToEvents = true
//                    }
                }
                .padding()
            }
            .navigationTitle("首页")
            .navigationDestination(isPresented: $navigateToGrades) { GradeInquiry() }
            .navigationDestination(isPresented: $navigateDebugRoom) { DebugRoom() }
            .navigationDestination(isPresented: $navigateToExams) { ExamView() }
            .navigationDestination(isPresented: $navigateToNanhuRun) { NanhuRunView() }
            .navigationDestination(isPresented: $navigateToPhysicalTest) { PhysicalTestView() }
            .navigationDestination(isPresented: $navigateToAllCoueseSearch) { AllCourseView() }
            .navigationDestination(isPresented: $navigateToSchoolCalender) { SchoolCalendarView() }
            .navigationDestination(isPresented: $navigateToBus)
            { SchoolBusView() }
            .navigationDestination(isPresented: $navigateElectricity)
            { ElectricityView() }
            .navigationDestination(isPresented: $navigateToClassroom)
            { ClassroomView() }
            .navigationDestination(isPresented: $navigateToEvents)
            { EventListView() }
            .navigationDestination(isPresented: $navigateToStrategy)
            { AllStrategy() }
            .navigationDestination(isPresented: $navigateToClub)
            { AllClub() }
        }
    }
}

struct MenuGridItem: View
{
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View
    {
        Button(action: action)
        {
            VStack(spacing: 12)
            {
                // 图标部分
                ZStack
                {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(color.opacity(0.15))
                        .frame(width: 60, height: 60)

                    Image(systemName: icon)
                        .font(.system(size: 26))
                        .foregroundColor(color)
                }

                // 文字部分
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(PlainButtonStyle()) // 去掉默认按钮高亮
    }
}

#Preview
{
    HomeView()
        .environmentObject(userInfo())
}
