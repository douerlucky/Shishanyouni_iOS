//
//  SchoolBusQuery.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/16.
//

import SwiftUI
import WebKit

// 使用 UIViewRepresentable 包装 WKWebView
struct SchoolBusWeb: UIViewRepresentable
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
