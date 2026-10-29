# 代码目录与职责

## 总体规则

主 App 按功能组织，不建立全应用级的 `Views`、`Service` 或 `Models` 大目录。
一个功能的页面、业务、请求和数据结构就近维护；只有真正跨功能复用的代码进入 `Core` 或 `UIComponents`。

```text
shishanyouni/
├── App/                         App 入口、Tab 和首次启动内容
├── Account/                     账号状态、凭据、登录与认证
│   ├── Views/
│   ├── Components/
│   ├── Models/
│   ├── Service/                 共用账号状态与加密
│   ├── SchoolDirect/
│   │   ├── API/                 学校认证及教学平台会话请求
│   │   ├── Models/
│   │   └── Service/             学校 Cookie 缓存与认证辅助逻辑
│   └── ShishanyouniBackend/
│       ├── API/                 V3 认证、业务传输及公开接口地址
│       ├── Models/
│       └── Service/             V3 会话、凭据存储及验证码呈现协调
├── Setting/                     全局设置，不再放在 Account
│   ├── Views/
│   ├── Models/
│   ├── Components/
│   └── Service/
├── ChooseCourse/                选课功能示例
│   ├── Views/
│   ├── API/
│   ├── Service/
│   ├── Models/
│   └── Components/
├── Curriculum/                  课表，保留已有三个子功能边界
│   ├── CurriculumView/
│   ├── CurriculumSetting/
│   ├── importCurriculum/
│   ├── Models/                  三个课表子功能共用的课程模型
│   └── Service/                 课表存储、导出、提醒与日历同步
├── Grade/、Exam/、Course/…       其他功能使用相同的内部规则
├── Core/                        跨功能的非界面基础能力
│   ├── Networking/
│   ├── Storage/
│   ├── Academic/
│   └── Configuration/
├── UIComponents/                跨功能共用按钮、选择器、卡片和材质
├── Widgets/Service/             主 App 到小组件的同步逻辑
├── Debug/                       调试页面，不放正式认证实现
└── Vendor/                      原有第三方源码与许可证
```

功能目录按实际需要增加子目录，不创建空的模板文件，也不要求一个类型对应一个文件。
多个相关的小组件可以放在同一个明确命名的组件文件中。页面较多时放入 `Views`；只有一个简单页面的功能可以保留在功能根目录。

## 功能内部如何放文件

| 目录 | 放什么 | 不放什么 |
| --- | --- | --- |
| `Views` | 页面布局、界面状态、用户操作与页面协调 | 直接构造 HTTP 请求、服务器字段解析 |
| `API` | URLRequest、请求头和表单、网络传输、接口响应解码与请求错误 | 页面布局、持久化偏好设置 |
| `Service` | 业务规则、导入转换、统计、存储、导出、ViewModel | 可复用卡片和按钮的布局 |
| `Models` | 本功能业务结构、接口 DTO、枚举和页面状态数据 | 网络请求、存储执行逻辑 |
| `Components` | 仅本功能使用的卡片、行、查询栏、输入组件 | 全应用共用的基础按钮 |

不为了分层增加空壳 Service：简单页面可以调用本功能 API；存在转换、组合或持久化规则时，再由 Service 协调。
同一 App target 内直接引用 Swift 类型，不按目录增加模块 `import`。

界面优先使用系统已有的 `Button`、`Picker`、`Toggle`、`DisclosureGroup`、`Form`、`Sheet` 和工具栏。
共用组件只封装重复规格，不重写系统已有的按压动画、选择菜单、弹窗遮罩或控件状态机。
课表网格、日历事件标记、图表等业务内容仍可自定义，不能为了“原生化”删掉所需信息。

选课模块的 `CourseCatalogService`、`CourseMutationService` 和 `CourseSelectionPageService` 负责目录组合、写入前核验与结果确认；`CourseSelectionAPI` 集中定义请求端点和重试规则，`CourseSelectionHTTP` 负责传输。选课、退课和志愿同步一律不自动重发。

## 账号与设置

- `Account/Service/UserInfo.swift` 是现有账号状态与本地凭据的共用入口；保留 `userInfo` 类型、UserDefaults 键和 Keychain 账户名。
- 学校直连与狮山有你后端的认证请求、响应模型和会话辅助代码分别放在对应子目录，不互相代替登录。
- 学校固定地址位于 `Account/SchoolDirect/API/SchoolDirectAPI.swift`，后端固定地址位于 `Account/ShishanyouniBackend/API/ShishanyouniAPI.swift`。
- 设置页面、偏好设置和背景图片管理属于 `Setting`。课程、成绩、日程等业务数据的唯一存储入口仍由对应功能的 Service 维护，不复制第二套缓存。
- 新增凭据继续使用 Keychain；不把真实账号、Cookie、Token 或密码写进测试、文档和日志。

## 课表导入

`Curriculum/importCurriculum/API` 只维护请求；`Service` 负责把响应转换为本地课程、匹配考核方式。

- `AcademicCurriculumAPI` + `AcademicCurriculumImporter`：学校直连，不访问狮山有你服务器。
- `ShishanyouniCurriculumAPI` + `ShishanyouniCurriculumImporter`：狮山有你后端导入。
- 两种来源保持独立选择，原有学期码、课程替换规则和默认开学日期不变。

后端个人业务已接入 V3：成绩、考试、课表和环湖跑共用门户凭据及按需续期；公开查询仍使用原路径。
课表 V3 的 `others` 转成没有固定节次的“其他课程”；两种来源仅共享纯文本周次解析，不共享登录或网络请求。
协议边界、凭据生命周期和离线验证方式见 [ios-v3-integration.md](ios-v3-integration.md)。

## 全局按钮

`UIComponents/Button.swift` 维护跨功能的主要操作：

- `AcceptButton`、`CancelButton`：默认占满父容器宽度，使用系统 `.large` 控件规格。
- `SearchButton`：始终只显示圆形搜索图标，标题仅用于 VoiceOver；与数据源、学期选择器共用 42pt 高度。
- `NextButton`：明确使用系统 `.buttonBorderShape(.circle)`，加减、翻页和周数栏收起按钮复用；不能用默认胶囊冒充圆形。
- 横排按钮各自填满分配到的空间，不改为上下两行。
- 共用样式通过 `Button(configuration)` 原样转发到 Apple 的 `.glass` / `.glassProminent`，不再组合 `.plain`、自画底板或 `.glass(.identity)`。
- 玻璃背景、点击范围和按压动画都由官方按钮样式负责；没有自定义 Button padding、玻璃描边或按压手势。
- 固定图标和 42pt 查询控件的 label 可伸缩，外层确定尺寸；`.buttonSizing(.flexible)` 让系统按钮使用提供的宽度，圆形控件使用 `.mini` 避免默认大号内容间距。
- 原生按钮不应用 App 的组件不透明度，也不叠加底色；按钮玻璃浓度完全交给系统。组件滑块仍调卡片和底栏背景，不影响文字/图标。
- 保留系统蓝与全局玻璃开关；关闭玻璃或旧系统时使用官方 `.bordered` / `.borderedProminent`，仍由系统绘制按钮。
- 系统工具栏、菜单项、Alert、列表导航行采用其原生样式，不额外套玻璃按钮。
- 原生玻璃按钮同样建立材质边界，避免 label 内的普通装饰再次绘制玻璃；关闭开关时不新增边界。

不要在业务页面重复拼接同一种确认、取消或搜索按钮的底色、圆角和固定宽度。
数据源使用系统 Menu + Picker，并明确 `.menuStyle(.button)`，直接给 Menu 应用官方 `.glass` / `.bordered` 样式，不经过 `Button(configuration)` 的 PrimitiveButtonStyle 转发封装；触发文字保持单行并自动缩小。日程和校历共用 `MonthNavigationControls`。
数据源触发器使用深色的常规玻璃染色，与外层浅色底栏区分；成绩、考试底栏默认是 Capsule，空教室多行底栏显式保留圆角矩形。
首页两套入口共用 `MenuGridItem`，结构为上方 60×60 图标 Button、下方独立 Text，玻璃不包住标题。
首页入口保留同色染色，玻璃底的 tint 使用图标色的 18% alpha；图标使用原色，两者浓淡分开。
常用功能与全部功能共用 `HomeFeatureGridView`，使用系统 `UICollectionView` 拖放代理及三列组合布局；全部功能保留分类，在分类内排序。
两套顺序由 `HomeLayer` 分开持久化；拖放期间不因时钟刷新而替换集合视图的数据。`scripts/test-home-order-offline.sh` 可在不启动模拟器的情况下验证排序存储，但不替代真机触摸测试。
长按图标直接进入真实编辑态并显示圆形加减号；拖放期间只刷新编辑标记，不重载或替换排序中的数组。

API 请求不放进 `UIComponents`，也不重新集中成一个全局业务大文件：功能端点留在各功能 `API`，共用传输放 `Core/Networking`，认证及服务地址按学校直连/后端边界集中维护。

## Liquid Glass 与系统设置

原生 Liquid Glass 自动适配系统外观和辅助功能偏好，不需要把系统滑杆值复制到 App 设置中。
代码中的 `.regular` / `.clear` 是材质变体，不是系统用户偏好的枚举值。
材质本身的透明效果跟随系统 Liquid Glass 和辅助功能设置。App 的组件不透明度是卡片和底栏的独立背景合成参数，不替代系统材质设置；原生按钮明确不受此滑块影响。
App 保留玻璃开关；卡片/底栏使用 `.glassEffect(.regular)`，不开启时使用普通颜色回退；按钮直接使用官方按钮样式，不再拼装玻璃背景。
`AppearanceOpacity.swift` 分别提供 `appTextOpacity()` 和 `componentBackgroundOpacity()`：前者只用于文字或 Label 的 title；后者只用于背景层。文字、图标、底板和背景图片不能再通过整张卡片的 `.opacity` 混在一起调节。
文字沿用旧 key `scheduleContentOpacity`；组件使用新 key `componentOpacity`，默认 100%，避免把旧版普通背景的 35% 错当作玻璃初始透明度。图片仍使用自己的设置。系统工具栏和 Sheet 保持原生，不额外包一层背景。
设置页说明：“单独的液态玻璃不透明度调节，请前往系统设置中的 Liquid Glass 调整。”转场自身的淡入淡出仍然保留。
依据：[Apple 的 Liquid Glass 适配说明](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)、[WWDC26 系统设置自动适配说明](https://developer.apple.com/videos/play/wwdc2026/102/)。

## 资源、旧稿与验证

- `Info.plist`、entitlements、Assets、资源文件及独立 Widget target 保持原位置；不把源文件整理混同为资源迁移。
- 旧 `Backup` 中仍在使用的教学平台认证实现已迁至 `Account/SchoolDirect/API/SchoolAcademicAPI.swift`。
- 真正的历史稿保留在仓库根目录 `Archive/LegacyCode`，不参与 App 编译；不是另一套正式实现。
- 新增 Swift 文件不要与同一 target 的其他文件重名，避免本地化字符串生成产物冲突。
- 工程使用文件系统同步分组，功能目录内新增的 Swift 文件会自动纳入 App target。
- 修改后至少检查格式并构建主 App；涉及模型、账号或公共组件时，同时构建对应测试包。测试包编译成功不代表测试已经执行。
