import SwiftUI

private enum HomeMenuColor
{
    static let red1 = Color.adaptive(light: Color(red: 0.89, green: 0.24, blue: 0.22), dark: Color(red: 0.95, green: 0.40, blue: 0.38))
    static let red2 = Color.adaptive(light: Color(red: 0.80, green: 0.18, blue: 0.30), dark: Color(red: 0.88, green: 0.35, blue: 0.45))
    static let orange1 = Color.adaptive(light: Color(red: 0.95, green: 0.47, blue: 0.18), dark: Color(red: 0.98, green: 0.60, blue: 0.35))
    static let orange2 = Color.adaptive(light: Color(red: 0.90, green: 0.58, blue: 0.16), dark: Color(red: 0.94, green: 0.68, blue: 0.32))
    static let yellow1 = Color.adaptive(light: Color(red: 0.86, green: 0.73, blue: 0.16), dark: Color(red: 0.90, green: 0.78, blue: 0.30))
    static let yellow2 = Color.adaptive(light: Color(red: 0.72, green: 0.76, blue: 0.18), dark: Color(red: 0.78, green: 0.80, blue: 0.32))
    static let green1 = Color.adaptive(light: Color(red: 0.26, green: 0.69, blue: 0.31), dark: Color(red: 0.35, green: 0.75, blue: 0.40))
    static let green2 = Color.adaptive(light: Color(red: 0.15, green: 0.71, blue: 0.47), dark: Color(red: 0.28, green: 0.76, blue: 0.55))
    static let cyan1 = Color.adaptive(light: Color(red: 0.12, green: 0.70, blue: 0.74), dark: Color(red: 0.28, green: 0.78, blue: 0.80))
    static let cyan2 = Color.adaptive(light: Color(red: 0.13, green: 0.63, blue: 0.86), dark: Color(red: 0.30, green: 0.72, blue: 0.90))
    static let blue1 = Color.adaptive(light: Color(red: 0.20, green: 0.49, blue: 0.92), dark: Color(red: 0.38, green: 0.62, blue: 0.95))
    static let blue2 = Color.adaptive(light: Color(red: 0.30, green: 0.40, blue: 0.88), dark: Color(red: 0.45, green: 0.52, blue: 0.92))
    static let purple1 = Color.adaptive(light: Color(red: 0.50, green: 0.34, blue: 0.86), dark: Color(red: 0.60, green: 0.48, blue: 0.92))
    static let purple2 = Color.adaptive(light: Color(red: 0.69, green: 0.34, blue: 0.78), dark: Color(red: 0.78, green: 0.48, blue: 0.85))
}

struct HomeView: View
{
    @State private var cookieInput = "No cookies yet."

    // 控制页面跳转状态
    @State private var navigateToGrades = false
    @State private var navigateDebugRoom = false
    @State private var navigateToExams = false
    @State private var navigateToNanhuRun = false
    @State private var navigateToPhysicalTest = false
    @State private var navigateToPhysicalTestCalculator = false
    @State private var navigateToAllCoueseSearch = false
    @State private var navigateToSchoolCalender = false
    @State private var navigateToBus = false
    @State private var navigateElectricity = false
    @State private var navigateToClassroom = false
    @State private var navigateToEvents = false
    @State private var navigateToStrategy = false
    @State private var navigateToClub = false
    @State private var navigateToGIS = false
    @State private var navigateToLibrary = false

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

    private var isGuestMode: Bool
    {
        userinfo.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

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

                        Spacer()
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
                        VStack(alignment: .leading, spacing: 8)
                        {
                            Text("当前为游客模式")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)

                            Text("欢迎使用狮山有你！\n来一起探索华中农业大学吧！")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)

                            Text("游客模式下可使用公开信息与本地工具功能，登录后可解锁个性化校园服务。")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
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

                    if !isGuestMode
                    {
                        MenuGridItem(title: "成绩查询", icon: "graduationcap.fill", color: HomeMenuColor.red1)
                        {
                            navigateToGrades = true
                        }

                        MenuGridItem(title: "考试查询", icon: "pencil.line", color: HomeMenuColor.orange1)
                        {
                            navigateToExams = true
                        }
                        MenuGridItem(title: "全校课程查询", icon: "mail.and.text.magnifyingglass", color: HomeMenuColor.yellow1)
                        {
                            navigateToAllCoueseSearch = true
                        }

                    }


                    MenuGridItem(title: "空教室查询", icon: "door.left.hand.open", color: HomeMenuColor.green1)
                    {
                        navigateToClassroom = true
                    }
                    

                    if !isGuestMode
                    {
                        MenuGridItem(title: "环湖跑查询", icon: "figure.run", color: HomeMenuColor.cyan1)
                        {
                            navigateToNanhuRun = true
                        }

                        MenuGridItem(title: "体测查询", icon: "figure.run.square.stack.fill", color: HomeMenuColor.blue1)
                        {
                            navigateToPhysicalTest = true
                        }
                    }
                    MenuGridItem(title: "体测计算器", icon: "plus.forwardslash.minus", color: HomeMenuColor.blue2)
                    {
                        navigateToPhysicalTestCalculator = true
                    }
                    
                    
                    if !isGuestMode
                    {
                        MenuGridItem(title: "宿舍电费", icon: "gauge.with.needle.fill", color: HomeMenuColor.purple1)
                        {
                            navigateElectricity = true
                        }
                        MenuGridItem(title: "图书馆预约（beta）", icon: "building.columns.fill", color: HomeMenuColor.cyan2)
                        {
                            navigateToLibrary = true
                        }
                    }
                    
                    MenuGridItem(title: "校园地图", icon: "map.fill", color: HomeMenuColor.green2)
                    {
                        navigateToGIS = true
                    }
                    
                    if #available(iOS 26.0, *)
                    {
                        MenuGridItem(title: "校历查询", icon: date + ".calendar", color: HomeMenuColor.purple2)
                        {
                            navigateToSchoolCalender = true
                        }
                    }
                    else
                    {
                        MenuGridItem(title: "校历查询", icon: "calendar", color: HomeMenuColor.purple2)
                        {
                            navigateToSchoolCalender = true
                        }
                    }
                    MenuGridItem(title: "校车查询", icon: "bus", color: HomeMenuColor.red2)
                    {
                        navigateToBus = true
                    }
                    MenuGridItem(title: "攻略", icon: "info.bubble", color: HomeMenuColor.orange2)
                    {
                        navigateToStrategy = true
                    }
                    MenuGridItem(title: "社团", icon: "person.2.fill", color: HomeMenuColor.yellow2)
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
            .navigationDestination(isPresented: $navigateToPhysicalTestCalculator) { PhysicalTestCalculatorView() }
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
            .navigationDestination(isPresented: $navigateToGIS)
            { SchoolGISView() }
            .navigationDestination(isPresented: $navigateToLibrary)
            { LibraryOverviewView() }
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
