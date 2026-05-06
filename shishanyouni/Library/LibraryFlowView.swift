import SwiftUI
import WebKit

struct LibraryFlowView: View
{
    @EnvironmentObject var userinfo: userInfo

    var body: some View
    {
        LibraryAdaptiveWeb(urlString: "https://libseat.hzau.edu.cn/self")
            .ignoresSafeArea(edges: .top)
            .navigationTitle("座位预约")
            .toolbar(.hidden, for: .tabBar)
            .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LibraryAdaptiveWeb: UIViewRepresentable
{
    let urlString: String

    func makeCoordinator() -> Coordinator
    {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView
    {
        let config = WKWebViewConfiguration()

        let vpScript = WKUserScript(
            source: """
            var m=document.querySelector('meta[name=viewport]');
            if(m)m.content='width=device-width,initial-scale=1.0,maximum-scale=5.0,user-scalable=yes';
            else{var n=document.createElement('meta');n.name='viewport';
            n.content='width=device-width,initial-scale=1.0,maximum-scale=5.0,user-scalable=yes';
            document.head.appendChild(n);}
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(vpScript)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_6 like Mac OS X) AppleWebKit/605.1.15"
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = UIColor.systemGroupedBackground
        webView.scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context)
    {
        if let url = URL(string: urlString)
        {
            uiView.load(URLRequest(url: url))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate
    {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!)
        {
            let css = """
            (function(){
            var s=document.getElementById('ioslib');
            if(!s){
            s=document.createElement('style');
            s.id='ioslib';
            document.head.appendChild(s);
            }
            s.textContent=''+
            ':root{--bg:#F2F2F7;--card:#FFFFFF;--txt:#1C1C1E;--sub:#8E8E93;--accent:#007AFF;--r:13px;--f:-apple-system,BlinkMacSystemFont,sans-serif}'+
            '*,body,html,div,p,span,a,li,td,th,h1,h2,h3,h4,h5,h6,dt,dd,input,button,select,textarea{font-family:var(--f)!important}'+
            'body,html{background:var(--bg)!important;margin:0!important;padding:0!important;overflow-x:hidden!important}'+
            '#update_browser_box{display:none!important}'+
            '.w960{width:100%!important;max-width:100vw!important}'+
            '.w960 .main_t,.w960 .main_b{display:none!important}'+
            '.w960 .main{width:100%!important;max-width:100%!important;background:none!important}'+
            '.top{display:none!important}'+
            '.login_main{display:flex!important;flex-direction:column!important;padding:0!important;width:100%!important}'+
            '.login_main .notice{width:100%!important;max-width:100vw!important;padding:0!important;float:none!important;display:block!important;overflow:visible!important}'+
            '.login_main .notice .bottom{width:100%!important;height:auto!important;padding:0!important;float:none!important;margin:0!important}'+
            '.login_main .notice .bottom .l,.login_main .notice .bottom .r{display:none!important}'+
            '.login_main .notice .bottom .mid{width:100%!important;height:auto!important;display:flex!important;gap:8px!important;flex-wrap:wrap!important;float:none!important;margin:0!important;padding:12px!important;background:var(--card)!important;border-radius:var(--r)!important;box-sizing:border-box!important}'+
            '.imgdiv{flex:1!important;min-width:80px!important;height:auto!important;border-radius:var(--r)!important;padding:16px 8px!important;margin:0!important;text-align:center!important;box-sizing:border-box!important;display:flex!important;flex-direction:column!important;align-items:center!important;justify-content:center!important}'+
            '.imgdiv p{font-size:28px!important;font-weight:700!important;color:#fff!important;margin:0!important;line-height:1.2!important}'+
            '.imgdiv p+p{font-size:12px!important;font-weight:500!important;margin-top:4px!important;opacity:0.85!important}'+
            '.imgdiv img{display:none!important}'+
            '.imgdiv>div{display:flex!important;flex-direction:column!important;align-items:center!important}'+
            '.left-announce{background:var(--card)!important;border-radius:var(--r)!important;padding:16px!important;margin:12px 0!important;width:100%!important;max-width:100%!important;height:auto!important;max-height:200px!important;overflow-y:auto!important;box-sizing:border-box!important;font-size:13px!important;line-height:1.8!important;color:var(--sub)!important}'+
            '.left-announce p{margin:0 0 6px!important;font-weight:400!important}'+
            '.login_main .form{width:100%!important;max-width:100%!important;float:none!important;padding:0!important}'+
            '.leftlogn{width:100%!important;max-width:100%!important;border:none!important;box-shadow:none!important;margin:0!important;border-radius:var(--r)!important;background:var(--card)!important;padding:24px 20px!important;box-sizing:border-box!important}'+
            '.login_main .form dl{width:100%!important;margin:0!important}'+
            '.login_main .form dl dt{font-size:20px!important;font-weight:700!important;color:var(--txt)!important;text-align:center!important;height:auto!important;padding:0 0 12px!important}'+
            '.btn1{width:100%!important;height:52px!important;border-radius:var(--r)!important;border:none!important;background:var(--accent)!important;color:#fff!important;font-size:17px!important;font-weight:600!important;line-height:52px!important;background-image:none!important;-webkit-appearance:none!important}'+
            '.qrcodeDiv img{width:180px!important;border-radius:var(--r)!important}'+
            'input,select,textarea{-webkit-appearance:none!important;width:100%!important;height:44px!important;border:1px solid #C6C6C8!important;border-radius:10px!important;padding:0 12px!important;font-size:16px!important;background:var(--card)!important;color:var(--txt)!important;box-sizing:border-box!important}'+
            '::-webkit-scrollbar{width:4px!important}'+
            '::-webkit-scrollbar-thumb{background:#C6C6C8!important;border-radius:2px!important}'+
            '.seatLayoutList,.seatTime,.dialog{width:100%!important;max-width:100vw!important;left:0!important;right:0!important;margin:0!important;box-sizing:border-box!important;border-radius:var(--r)!important}'+
            '.roomList a,.seatLayout a,.startTime a,.endTime a{padding:14px!important;display:block!important;border-radius:10px!important;margin:6px!important;background:var(--card)!important;color:var(--txt)!important;font-size:16px!important;text-decoration:none!important}'+
            '.loading2{background:rgba(0,0,0,0.15)!important}'+
            '@media(prefers-color-scheme:dark){:root{--bg:#000000;--card:#1C1C1E;--txt:#FFFFFF;--sub:#98989D}}';
            })();
            """
            webView.evaluateJavaScript(css, completionHandler: nil)
        }
    }
}

#Preview
{
    NavigationStack
    {
        LibraryFlowView()
            .environmentObject(userInfo())
    }
}
