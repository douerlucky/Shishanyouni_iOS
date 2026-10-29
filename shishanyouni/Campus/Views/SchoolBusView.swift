import SwiftUI
import WebKit

// 专门用来显示推文的 View
struct SchoolBusView: View
{

    var body: some View
    {
        SchoolBusWeb(urlString: SchoolDirectAPI.campusBusURL)
            .navigationTitle("校车查询")
            .toolbar(.hidden, for: .tabBar)
            .navigationBarTitleDisplayMode(.inline)
        // 如果你想隐藏整个导航栏来实现“全屏”网页效果：
    }
}

#Preview
{
    SchoolBusView()
}
