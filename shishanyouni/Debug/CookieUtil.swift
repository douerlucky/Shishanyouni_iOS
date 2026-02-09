import Foundation

import WebKit

struct CookieUtil
{
    static func getJSessionID(from webView: WKWebView, completion: @escaping (String?) -> Void)
    {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies
        { cookies in
            let js = cookies.first { $0.name == "JSESSIONID" }
            completion(js.map { "JSESSIONID=\($0.value)" })
        }
    }

    static func dumpAllCookies(from webView: WKWebView, completion: @escaping (String) -> Void)
    {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies
        { cookies in
            let text = cookies.map { "\($0.domain)\n\($0.name)=\($0.value)\n" }
                .joined(separator: "\n")
            completion(text)
        }
    }
}
