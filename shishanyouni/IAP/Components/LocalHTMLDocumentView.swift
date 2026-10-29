import StoreKit
import SwiftUI
import UIKit
import WebKit

struct LocalHTMLDocumentView: View
{
    let title: String
    let resourceName: String

    var body: some View
    {
        Group
        {
            if let fileURL = Bundle.main.url(forResource: resourceName, withExtension: "html")
            {
                LocalHTMLWebView(fileURL: fileURL)
            }
            else
            {
                VStack(spacing: 12)
                {
                    Image(systemName: "doc.questionmark")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text("页面暂时不可用")
                        .font(.headline)

                    Text("未能找到对应的本地说明文件。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LocalHTMLWebView: UIViewRepresentable
{
    let fileURL: URL

    func makeUIView(context: Context) -> WKWebView
    {
        let webView = WKWebView(frame: .zero)
        webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
