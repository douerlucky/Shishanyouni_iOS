import SwiftUI
import UIKit
import WebKit

// MARK: - 校历原文网页

struct SchoolCalendarOriginalWebView: View
{
    let urlString: String

    var body: some View
    {
        SchoolCalendarWeb(urlString: urlString)
            .background(Color(.systemBackground))
            .navigationTitle("校历原文")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
    }
}
