import SwiftUI
import WebKit

struct SchoolGISWeb: UIViewRepresentable
{
    let urlString: String

    func makeUIView(context: Context) -> WKWebView
    {
        let webView = WKWebView()
        // 允许侧滑返回
        webView.allowsBackForwardNavigationGestures = true
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context)
    {
        if let url = URL(string: urlString)
        {
            let request = URLRequest(url: url)
            uiView.load(request)
        }
    }
}
