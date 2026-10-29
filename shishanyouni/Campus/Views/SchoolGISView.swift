import SwiftUI
import WebKit

// 专门用来显示地理信息
struct SchoolGISView: View
{
    var body: some View
    {
        SchoolGISWeb(urlString: SchoolDirectAPI.campusMapURL)

            .navigationTitle("校园地图")
            .toolbar(.hidden, for: .tabBar)
            .navigationBarTitleDisplayMode(.inline)
            .ignoresSafeArea(edges: .bottom) // 让网页铺满到底部
    }
}

#Preview
{
    SchoolGISView()
}
