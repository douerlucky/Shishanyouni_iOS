//
//  Xiaoli.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/16.
//

import SwiftUI

import SwiftUI
import WebKit

// 使用 UIViewRepresentable 包装 WKWebView
struct SchoolCalendarWeb: UIViewRepresentable
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

// 专门用来显示推文的 View
struct SchoolCalendarView: View
{
    let url: String = "https://open.work.weixin.qq.com/wwopen/mpnews?mixuin=lu0DCgAABwCtk1udAAAUAA&mfid=WW0313-r02y_AAABwD-jQWRBOWZ_Q52-zt98&idx=0&sn=d9818177ae6ac23d94424b331809cfd4"

    var body: some View
    {
        SchoolCalendarWeb(urlString: url)

            .navigationTitle("校历详情")
            .toolbar(.hidden, for: .tabBar)
            .navigationBarTitleDisplayMode(.inline)
            .ignoresSafeArea(edges: .bottom) // 让网页铺满到底部
    }
}

#Preview
{
    SchoolCalendarView()
}
