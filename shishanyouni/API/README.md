# API 目录

- `SchoolDirectAPI.swift`：学校系统直连接口、Origin、Referer 等固定地址。
- `ShishanyouniAPI.swift`：狮山有你后端接口的固定地址。
- `Models/`：按业务分类的接口请求、响应以及服务端原始数据。

维护约定：

1. URL 变化只修改地址文件；字段变化只修改对应的接口模型。
2. 网络请求、登录会话、错误处理仍放在各业务 Service 中；界面状态留在 View / ViewModel 中。
3. `Course`、`Grade`、`Exam` 等同时用于本地缓存或业务计算的模型保留在原模块。
4. 简单的图书、攻略、社团等数据可直接供界面展示，不为分层而重复定义一套相同结构。
5. 同一 App target 内直接使用类型名，无需按文件夹添加 `import`。

本轮只迁移已有的类型化模型，不改变仍使用字典或表单的请求参数、成功状态码和字段兼容规则。新增模型时请用 `APIModelTests` 中的脱敏样本验证编码 / 解码，不把真实账号、密码、Cookie 或 token 放进测试。
