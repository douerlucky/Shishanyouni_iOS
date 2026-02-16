//
//  SchoolBusQuery.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/16.
//

import SwiftUI

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
    let BusUrl: String = "https://car.hzau.edu.cn/passenger/pages/map"

    var body: some View
    {
        SchoolBusWeb(urlString: BusUrl)
            // 关键点：这里指定忽略 .top，去掉顶部的空白
            .ignoresSafeArea(edges: .top)
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
