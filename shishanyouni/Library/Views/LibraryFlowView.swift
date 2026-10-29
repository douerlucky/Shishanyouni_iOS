import SwiftUI
import WebKit

struct LibraryFlowView: View
{
    @EnvironmentObject var userinfo: userInfo

    var body: some View
    {
        LibraryAdaptiveWeb(urlString: SchoolDirectAPI.librarySeatURL)
            .navigationTitle("座位预约")
            .toolbar(.hidden, for: .tabBar)
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview
{
    NavigationStack
    {
        LibraryFlowView()
            .environmentObject(userInfo())
    }
}
