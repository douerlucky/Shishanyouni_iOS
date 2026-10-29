import SwiftUI
import WebKit

// MARK: - 自适应高度 WKWebView

struct DynamicHTMLView: UIViewRepresentable {
    let htmlString: String
    @Binding var height: CGFloat

    private var wrapped: String {
        """
        <!DOCTYPE html><html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
        <meta name="referrer" content="no-referrer">
        <style>
          :root { --text-color: #1c1c1e; --p-color: #3a3a3c; }
          @media (prefers-color-scheme: dark) { :root { --text-color: #f2f2f7; --p-color: #e5e5ea; } }
          body { font-family: -apple-system, sans-serif; font-size: 15px;
                 line-height: 1.75; color: var(--text-color); margin: 0; padding: 0 10px;
                 word-break: break-word; overflow: hidden;
                 /* 保险：在 HTML 内部加一个底边距，防止被截断 */
                 padding-bottom: 60px !important;
          }
          img { max-width: 100%; height: auto; border-radius: 10px; margin-top: 8px; display: block; }
        </style>
        </head>
        <body>
            <div id="content_wrapper">\(htmlString)</div>
            <script>
                const wrapper = document.getElementById('content_wrapper');
                const notifyHeight = () => {
                    // 使用 offsetHeight 获取包含 padding 的高度
                    window.webkit.messageHandlers.heightHandler.postMessage(wrapper.offsetHeight);
                };
                // 1. 监听尺寸变化
                const observer = new ResizeObserver(notifyHeight);
                observer.observe(wrapper);
                // 2. 监听所有图片加载完成
                window.onload = notifyHeight;
                // 3. 预防性延迟通知
                setTimeout(notifyHeight, 500);
                setTimeout(notifyHeight, 2000);
            </script>
        </body></html>
        """
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "heightHandler")
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.scrollView.isScrollEnabled = false // 禁用内部滚动
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.backgroundColor = .clear
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {
        if context.coordinator.lastLoadedHTML != wrapped {
            context.coordinator.lastLoadedHTML = wrapped
            wv.loadHTMLString(wrapped, baseURL: URL(string: ShishanyouniAPI.origin))
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: DynamicHTMLView
        var lastLoadedHTML: String = ""
        init(_ p: DynamicHTMLView) { parent = p }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "heightHandler", let h = message.body as? CGFloat {
                // 如果检测到的高度比当前记录的大，且变化超过 5 像素，则更新
                if h > 0 && abs(parent.height - h) > 5 {
                    DispatchQueue.main.async {
                        // 加上缓冲区间，彻底杜绝截断
                        self.parent.height = h + 40
                    }
                }
            }
        }
    }
}

#Preview
{
    NavigationView { StrategyDetailView(guideId: 1) }
}
