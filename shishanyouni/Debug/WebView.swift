//
//  WebView.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/5.
//
import SwiftUI
import WebKit

struct WebView: UIViewRepresentable
{
    let url: URL
    @Binding var webViewRef: WKWebView?

    func makeUIView(context: Context) -> WKWebView
    {
        let web = WKWebView(frame: .zero)
        web.navigationDelegate = context.coordinator
        webViewRef = web
        web.load(URLRequest(url: url))
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate
    {
        // 只跳一次，避免循环跳转
        private var didOpenJWGL = false

        // 你要“种 Cookie”的 jwgl 页面（随便一个 jwgl 页面都行）
        private let gradePage = URL(string: "http://jwgl.hzau.edu.cn/sso/hnyyxyiotlogin")!

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!)
        {
            let current = webView.url?.absoluteString ?? "(nil)"
            print("WKWebView didFinish:", current)

            // 1) 识别“登录成功后进了 portal 主页面”
            //    你日志里就是 https://portal-paas.hzau.edu.cn/main.html
            if !didOpenJWGL,
               let host = webView.url?.host,
               host.contains("portal-paas.hzau.edu.cn"),
               current.contains("/main.html")
            {
                didOpenJWGL = true
                print("✅ Portal main loaded. Now open jwgl once to get JSESSIONID...")

                // 2) 打开一次 jwgl（让 jwgl 下发 JSESSIONID）
                webView.load(URLRequest(url: gradePage))
            }
        }
    }
}
