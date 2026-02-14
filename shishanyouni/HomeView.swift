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
                    MenuGridItem(title: "Debug页面", icon: "ladybug.fill", color: .orange)
                    {
                        navigateDebugRoom = true
                    }
                    
                    MenuGridItem(title: "成绩查询", icon: "graduationcap.fill", color: .blue)
                    {
                        navigateToGrades = true
                    }
                    
                    MenuGridItem(title: "考试查询", icon: "pencil.line", color: .green)
                    {
                        navigateToExams = true
                    }
                    
                    MenuGridItem(title: "环湖跑查询", icon: "figure.run", color: .brown)
                    {
                        navigateToNanhuRun = true
                    }
                    
                    MenuGridItem(title: "体测查询", icon: "figure.run.square.stack.fill", color: .red)
                    {
                        navigateToPhysicalTest = true
                    }
                }
                .padding()
            }
            .navigationTitle("首页")
            .navigationDestination(isPresented: $navigateToGrades) { GradeInquiry() }
            .navigationDestination(isPresented: $navigateDebugRoom) { DebugRoom() }
            .navigationDestination(isPresented: $navigateToExams) {ExamView()}
            .navigationDestination(isPresented: $navigateToNanhuRun) {NanhuRunView()}
            .navigationDestination(isPresented: $navigateToPhysicalTest) {PhysicalTestView()}
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
