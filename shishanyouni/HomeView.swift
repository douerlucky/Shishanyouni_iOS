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
