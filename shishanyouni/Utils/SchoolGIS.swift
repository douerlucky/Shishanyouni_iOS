//
//  Xiaoli.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/16.
//

import SwiftUI

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

// 专门用来显示地理信息
struct SchoolGISView: View
{
    let url: String = "http://gis.hzau.edu.cn/index.shtml"

    var body: some View
    {
        SchoolCalendarWeb(urlString: url)

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
