# 狮山有你 iOS V3 接入

协议依据：2026-10-27 的《iOS-v3 接入说明》。入口为 `https://lion.hzau.edu.cn/app/ios/v3`，全部 JSON POST。

## 范围与职责

- `Account/ShishanyouniBackend/API/ShishanyouniV3API.swift`：HTTP 字段白名单、传输与包装层解码。POST 不自动重发。
- `Account/ShishanyouniBackend/Service/ShishanyouniV3Session.swift`：按账号管理门户/子系统会话、单飞续期、验证码和退出失效。
- `Account/ShishanyouniBackend/Service/ShishanyouniV3CredentialStore.swift`：独立 V3 Keychain 记录。
- `ShishanyouniMFAPresenter` 与 `UIComponents/ShishanyouniMFASheet.swift`：统一验证码输入，等待 Sheet 完成收起后恢复业务。
- `Grade/API`、`Exam/API`、`GymCloud/API`、`Curriculum/importCurriculum/API`：各自业务解码，不再自行处理登录/续期。

学校直连登录和查询保持独立。空教室、全校课程、馆藏、攻略、社团等公开接口没有 V3 替代地址，保留原路径。

## 请求与凭据规则

1. 仅 `bind` 发送密码，沿用 RSA PKCS#1 v1.5 + Base64 + `_RSA`，`type` 固定为数字 `1`。
2. 成绩和考试仅传 `xnm/xqm/yhm/portalToken/jwxtToken`；课表仅传 `year/term/username/portalToken/jwxtToken`；环湖跑不传教务子会话。
3. `sendCode` 和 `submitCode` 参数在 JSON 中。短信验证成功读取 `{portalToken, expireAt}`，不再读取旧版字符串 token。
4. 顶层 `token` 是 `jwxtToken`，出现立即保存，缺失保持原值。`expireAt` 只保存，不据此判定登录失效。
5. 冷启动只读本地凭据。旧版升级没有 V3 凭据时，在实际查询时按需登录；不发后台保活请求。
6. `code=23` 合并为一个续期任务；30 秒内复用新门户凭据。单个业务请求最多自动续期一次，重放仍失效即停止并提示重新绑定。
7. `code=22` 进入统一短信界面；输错可重输，最多五次。会话已过期/作废时展示服务端说明，等待用户主动重新绑定，不循环登录。
8. 同一短信会话成功发送后冷却 60 秒；关闭重开 Sheet 仍保留倒计时。
9. `code=3/5` 直接展示服务端 `msg`，不改成通用 401。
10. 续期失败清门户及子会话，不删除已保存的账号密码。主动退出立即清本地，尽力异步调用 `revoke`，不等待网络；旧请求不能恢复被退出或替换的会话。

不把旧 Keychain token 当成门户 token。成功写入 V3 凭据时删除旧 token；“记住密码”只影响密码持久化，不删除仍有效的门户凭据。

## 业务兼容

- V3 成绩接口只声明学期 `1/2`。“全学年/所有成绩”在客户端串行查询并合并，跳过当前尚未开始的第二学期，不向服务端发送未声明的 `xqm=0`。
- 课表兼容 `weeks`、旧字段 `week` 及 `time`。`others` 的 `○/◇` 分隔说明转换成 `.other` 课程，保留周次，星期/节次为零，只在“所有课程”展示。
- 课表字段损坏时报错，不静默丢弃课程或覆盖已有课表。学校直连导入仍使用自身开学日期及学校接口。

## 无模拟器验证

在项目根目录执行：

```sh
zsh scripts/test-v3-offline.sh
```

该脚本编译并执行生产会话/API/课表解析代码，通过 URLProtocol 拦截全部请求；不访问学校或后端、不读取真实账号、不启动模拟器。
相同场景也纳入 `shishanyouniTests/ShishanyouniV3Tests.swift`，可由 Xcode 在合适设备上执行。

覆盖请求字段、缓存凭据、并发单飞、30 秒防频繁登录、二次失效停止、续期失败、三条 MFA 路径、取消验证、短信冷却/发送失败、退出/重新绑定竞态、等待者取消、服务端错误原文，以及未排课课程导入。

离线验证不能替代真实服务器联调、真机验证码交互、多设备互踢或 iOS/小程序渠道隔离验证。
