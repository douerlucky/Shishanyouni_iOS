import SwiftUI

struct ContentView: View
{
    @State private var cookieInput = "No cookies yet."
   

    // 控制页面跳转状态
    @State private var navigateToGrades = false
    @State private var navigateDebugRoom = false
    
    @EnvironmentObject var userinfo: userInfo

    var body: some View
    {
        NavigationStack
        {
            VStack(spacing: 16)
            {
                Button("打开Debug页面")
                {
                    navigateDebugRoom = true
                }
                .buttonStyle(.borderedProminent)
                
                Button("查询成绩（2025 学年 第 3 学期）")
                {
                    Task
                    {
                        navigateToGrades = true
                    }
                }
                .buttonStyle(.borderedProminent)
                
                Button("当前学号密码")
                {
                    userinfo.debugprint()
                }
            }
            .padding()
            .navigationTitle("首页")
            .navigationDestination(isPresented: $navigateToGrades)
            {
                GradeInquiry()
                    .navigationTitle("成绩查询")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .navigationDestination(isPresented: $navigateDebugRoom)
            {
                DebugRoom()
                    .navigationTitle("Debug房间")
                    .navigationBarTitleDisplayMode(.inline)
            }

        }
    }
}

#Preview
{
    ContentView()
        .environmentObject(userInfo())
        
}
