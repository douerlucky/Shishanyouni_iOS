# 狮山有你 iOS

华中农业大学（HZAU）校园生活助手 iOS App，将校内多个信息系统的查询功能整合到一个移动端界面中。

## 主要功能

| 功能 | 说明 | 需登录 |
|---|---|---|
| 课表查询 | 周视图课表，支持手动添加课程 | 是 |
| 成绩查询 | 课程成绩、学分绩点、学期 GPA 分析 | 是 |
| 考试查询 | 考试时间/地点/座位号，可添加到系统日历 | 是 |
| 全校课程查询 | 搜索全校课程、查看课程详情和时间表 | 是 |
| 空教室查询 | 按教学楼/楼层/日期查找空闲教室 | 否 |
| 环湖跑查询 | 南湖跑步记录（体育成绩组成部分） | 是 |
| 体测查询 | 体测各项目成绩及等级 | 是 |
| 体测计算器 | 手动估算体测分数 | 否 |
| 宿舍电费 | 查询宿舍电费余额和用量，支持后台定时监控 | 是 |
| 图书馆座位 | 实时图书馆各楼层座位使用情况 | 否 |
| 校园地图 | GIS 校园地图 WebView | 否 |
| 校历查询 | 学年校历（企业微信文章） | 否 |
| 校车查询 | 校园巴士实时位置追踪 | 否 |
| 攻略 | 校园生活攻略/贴士 | 否 |
| 社团 | 全部学生社团 A-Z 索引，支持搜索 | 否 |

### 其他特性
- **访客模式**：无需登录即可使用大部分公开信息功能
- **课表桌面小组件**：iOS 主屏幕 Widget 展示本周课表
- **CAS 统一认证**：支持带短信验证码的多因素认证
- **校园通行证**：应用内订阅服务（StoreKit 2，学期/学年方案）
- **电费后台监控**：基于 BGTaskScheduler 的宿舍电费余额定时检查

## 技术栈

- **语言**：Swift 100%
- **UI 框架**：SwiftUI（部分 UIKit 桥接用于 WKWebView 和 UITabBar 样式）
- **最低系统要求**：iOS 17.0+
- **包管理**：无 CocoaPods/SPM，依赖库直接集成（vendor-integrated）
- **加密**：RSA PKCS1（双公钥：学校 CAS + 狮山有你后端）

### 主要系统框架
- SwiftUI / UIKit / WidgetKit
- StoreKit 2（应用内购买）
- BackgroundTasks（后台任务）
- WebKit / Security / EventKit

## 项目结构

```
├── shishanyouni.xcodeproj/
├── shishanyouni/                  # 主应用
│   ├── shishanyouniApp.swift      # @main 入口
│   ├── MainTabView.swift          # 三Tab布局：课表/首页/我的
│   ├── HomeView.swift             # 首页功能宫格
│   ├── Data/                      # 数据模型 & 状态管理
│   ├── Account/                   # 登录/绑定/个人中心/RSA
│   ├── Schedule/                  # 课表
│   ├── Grade/                     # 成绩
│   ├── Exam/                      # 考试
│   ├── Course/                    # 全校课程
│   ├── Electricity/               # 宿舍电费
│   ├── GymCloud/                  # 环湖跑 & 体测
│   ├── Classroom/                 # 空教室
│   ├── Library/                   # 图书馆座位
│   ├── Event/                     # 日历事件
│   ├── IAP/                       # 应用内购买
│   ├── Utils/                     # 工具类 & 校园功能（地图/校车/校历/攻略/社团）
│   ├── Widgets/                   # 小组件数据共享
│   ├── Debug/                     # 调试工具
│   └── Daily/                     # （预留）
├── ScheduleWidget/                # 桌面小组件扩展
├── SwiftyRSA_Src/                 # SwiftyRSA 源码
├── shishanyouniTests/
└── shishanyouniUITests/
```

## 开发团队

- **沸点工作室 移动App开发组**
- UI 设计：douer_lucky
- iOS 开发：douer_lucky、澜沧

## 版本

当前版本 1.2（2026年3月）
