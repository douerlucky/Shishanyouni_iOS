import Foundation
import Testing
@testable import shishanyouni

struct CASLoginFailureTests
{
    private let fallback = "统一身份认证（智慧狮山）登录未完成，请重试；若仍失败，请在学校登录页确认验证要求。"

    @Test("CAS 错误数组可解码 JavaScript 中的 Unicode 转义")
    func decodesJavaScriptError()
    {
        let html = #"<script>var hasErrors = true; var errors = ["\u9a8c\u8bc1\u7801\u9519\u8bef"]; </script>"#
        #expect(CASLoginFailure.message(from: Data(html.utf8)) == "验证码错误")
    }

    @Test("CAS 登录错误块只保留用户可读文字")
    func readsHTMLErrorBlock()
    {
        let html = #"<div id="loginError1"><span>登录会话已过期</span>&nbsp;请重试</div>"#
        #expect(CASLoginFailure.message(from: Data(html.utf8)) == "登录会话已过期 请重试")
        let alertHTML = #"<div id="loginError1"><div><el-alert title="安全验证未完成" type="error"></el-alert></div></div>"#
        #expect(CASLoginFailure.message(from: Data(alertHTML.utf8)) == "安全验证未完成")
    }

    @Test("静态验证码提示和未激活的错误数组不会误报为登录错误")
    func ignoresStaticPageContent()
    {
        let html = #"<div id="loginError1"></div><p>验证码错误时请刷新图片</p><script>var hasErrors = false; var errors = ["账号或密码错误"];</script>"#
        #expect(CASLoginFailure.message(from: Data(html.utf8)) == fallback)
    }

    @Test("无明确错误时给出通用提示并保留 LoginFailed 错误类型")
    func fallsBackWithoutError()
    {
        let data = Data("<html><body>登录页面</body></html>".utf8)
        let error = CASLoginFailure.error(from: data)
        #expect(error.domain == "LoginFailed")
        #expect(error.code == 401)
        #expect(error.localizedDescription == fallback)
        #expect(CASLoginFailure.message(from: Data([0xFF])) == fallback)
    }

    @Test("错误区中的会话令牌不展示给用户")
    func doesNotExposeSessionFields()
    {
        let html = #"<div id="loginError1">execution=private-session-state</div>"#
        #expect(CASLoginFailure.message(from: Data(html.utf8)) == fallback)
    }
}
