//
//  StrategyDetailView.swift
//  shishanyouni
//

import SwiftUI
import WebKit

// MARK: - 数据模型

struct GuideDetail: Codable
{
    let id: Int
    let name: String
    let icon: String?
    let context: String?
    let author: String?
    let time: String?
}

struct GuideDetailResponse: Codable
{
    let msg: String
    let code: Int
    let data: GuideDetail?
}

// MARK: - ViewModel

class StrategyDetailViewModel: ObservableObject
{
    @Published var guide: GuideDetail? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    func fetchDetail(id: Int)
    {
        guard let url = URL(string: "https://lion.hzau.edu.cn/app/ios/guide/findbyid?id=\(id)") else { return }
        isLoading = true
        errorMessage = nil

        URLSession.shared.dataTask(with: url)
        { data, _, error in
            DispatchQueue.main.async
            {
                self.isLoading = false
                if let error = error { self.errorMessage = "请求失败：\(error.localizedDescription)"; return }
                guard let data = data else { self.errorMessage = "无数据返回"; return }
                do
                {
                    let result = try JSONDecoder().decode(GuideDetailResponse.self, from: data)
                    self.guide = result.data
                    if self.guide == nil { self.errorMessage = "未找到该攻略" }
                }
                catch { self.errorMessage = "解析失败：\(error.localizedDescription)" }
            }
        }.resume()
    }
}

// MARK: - 自适应高度 WKWebView

struct DynamicHTMLView: UIViewRepresentable
{
    let htmlString: String
    @Binding var height: CGFloat

    private var wrapped: String
    {
        """
        <!DOCTYPE html><html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
        <style>
          /* 定义默认（浅色）模式下的颜色变量 */
          :root {
            --text-color: #1c1c1e;
            --p-color: #3a3a3c;
          }

          /* 监听系统暗色模式，并动态替换颜色变量 */
          @media (prefers-color-scheme: dark) {
            :root {
              --text-color: #f2f2f7; /* Apple 官方暗色模式的次级文字亮色 */
              --p-color: #e5e5ea;
            }
          }

          body { font-family: -apple-system, sans-serif; font-size: 15px;
                 line-height: 1.75; color: var(--text-color); margin: 0; padding: 0 2px;
                 word-break: break-word; }
          h3   { font-size: 16px; font-weight: 600; margin-top: 20px; margin-bottom: 6px; }
          p    { margin: 6px 0; color: var(--p-color); }
          img  { max-width: 100%; border-radius: 10px; margin-top: 8px; }
        </style>
        </head>
        <body>\(htmlString)</body></html>
        """
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView
    {
        let wv = WKWebView()
        wv.navigationDelegate = context.coordinator
        wv.scrollView.isScrollEnabled = false
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.backgroundColor = .clear
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context)
    {
        wv.loadHTMLString(wrapped, baseURL: URL(string: "https://lion.hzau.edu.cn"))
    }

    class Coordinator: NSObject, WKNavigationDelegate
    {
        var parent: DynamicHTMLView
        init(_ p: DynamicHTMLView) { parent = p }
        func webView(_ wv: WKWebView, didFinish _: WKNavigation!)
        {
            wv.evaluateJavaScript("document.body.scrollHeight")
            { r, _ in
                if let h = r as? CGFloat
                {
                    DispatchQueue.main.async { self.parent.height = h }
                }
            }
        }
    }
}

// MARK: - 详情主视图

struct StrategyDetailView: View
{
    let guideId: Int
    @StateObject private var viewModel = StrategyDetailViewModel()
    @State private var webHeight: CGFloat = 300

    var body: some View
    {
        ScrollView
        {
            if viewModel.isLoading
            {
                VStack(spacing: 16)
                {
                    ProgressView().scaleEffect(1.4)
                    Text("加载中...").foregroundColor(.secondary).font(.subheadline)
                }
                .frame(maxWidth: .infinity).padding(.top, 100)
            }
            else if let error = viewModel.errorMessage
            {
                VStack(spacing: 16)
                {
                    Image(systemName: "wifi.exclamationmark").font(.system(size: 48)).foregroundColor(.secondary)
                    Text(error).foregroundColor(.secondary).font(.subheadline)
                        .multilineTextAlignment(.center).padding(.horizontal)
                    Button("重新加载") { viewModel.fetchDetail(id: guideId) }.buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity).padding(.top, 100)
            }
            else if let guide = viewModel.guide
            {
                VStack(alignment: .leading, spacing: 0)
                {
                    // 头部
                    HStack(spacing: 16)
                    {
                        AsyncImage(url: URL(string: guide.icon ?? ""))
                        { phase in
                            switch phase
                            {
                            case let .success(img): img.resizable().scaledToFit()
                            case .failure: Image(systemName: "photo").resizable().scaledToFit().foregroundColor(.gray)
                            default: ProgressView()
                            }
                        }
                        .frame(width: 48, height: 48)
                        .padding(16)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        VStack(alignment: .leading, spacing: 5)
                        {
                            Text(guide.name).font(.title2).fontWeight(.bold)
                            if let author = guide.author
                            {
                                Label(author, systemImage: "person.circle").font(.caption).foregroundColor(.secondary)
                            }
                            if let time = guide.time
                            {
                                Label(time, systemImage: "calendar").font(.caption).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(20)

                    Divider()

                    // HTML 正文
                    if let ctx = guide.context, !ctx.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    {
                        DynamicHTMLView(htmlString: ctx, height: $webHeight)
                            .frame(height: webHeight)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                    }
                    else
                    {
                        Text("暂无详细内容").foregroundColor(.secondary).padding(20)
                    }
                }
            }
        }
        .navigationTitle(viewModel.guide?.name ?? "攻略详情")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.fetchDetail(id: guideId) }
    }
}

#Preview
{
    NavigationView { StrategyDetailView(guideId: 1) }
}
