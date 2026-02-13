import SwiftUI

struct HomeView: View
{
    @State private var cookieInput = "No cookies yet."

    // 控制页面跳转状态
    @State private var navigateToGrades = false
    @State private var navigateDebugRoom = false

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
                    // 按钮 1
                    MenuGridItem(title: "Debug页面", icon: "ladybug.fill", color: .orange)
                    {
                        navigateDebugRoom = true
                    }

                    // 按钮 2
                    MenuGridItem(title: "成绩查询", icon: "graduationcap.fill", color: .blue)
                    {
                        navigateToGrades = true
                    }

                    // 按钮 3 (占位示例)
                    MenuGridItem(title: "考试查询", icon: "pencil.line", color: .green)
                    {
                        // TODO: 校园卡逻辑
                    }
                }
                .padding()
            }
            .navigationTitle("首页")
            .navigationDestination(isPresented: $navigateToGrades) { GradeInquiry() }
            .navigationDestination(isPresented: $navigateDebugRoom) { DebugRoom() }
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
