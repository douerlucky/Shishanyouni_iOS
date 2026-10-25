import Combine
import SwiftUI
import UIKit

// 首页职责：
// 1. 在 allFeatures 定义所有入口及其跳转动作；
// 2. 通过 HomeLayer 选出首页常用入口；
// 3. 用两段连续的滚动叠层承载收藏和全部功能，避免分页器与嵌套滚动抢手势。

private enum HomeMenuColor
{
    static let red1 = Color.adaptive(light: Color(red: 0.89, green: 0.24, blue: 0.22), dark: Color(red: 0.95, green: 0.40, blue: 0.38))
    static let red2 = Color.adaptive(light: Color(red: 0.80, green: 0.18, blue: 0.30), dark: Color(red: 0.88, green: 0.35, blue: 0.45))
    static let orange1 = Color.adaptive(light: Color(red: 0.95, green: 0.47, blue: 0.18), dark: Color(red: 0.98, green: 0.60, blue: 0.35))
    static let orange2 = Color.adaptive(light: Color(red: 0.90, green: 0.58, blue: 0.16), dark: Color(red: 0.94, green: 0.68, blue: 0.32))
    static let yellow1 = Color.adaptive(light: Color(red: 0.86, green: 0.73, blue: 0.16), dark: Color(red: 0.90, green: 0.78, blue: 0.30))
    static let yellow2 = Color.adaptive(light: Color(red: 0.72, green: 0.76, blue: 0.18), dark: Color(red: 0.78, green: 0.80, blue: 0.32))
    static let green1 = Color.adaptive(light: Color(red: 0.26, green: 0.69, blue: 0.31), dark: Color(red: 0.35, green: 0.75, blue: 0.40))
    static let green2 = Color.adaptive(light: Color(red: 0.15, green: 0.71, blue: 0.47), dark: Color(red: 0.28, green: 0.76, blue: 0.55))
    static let cyan1 = Color.adaptive(light: Color(red: 0.12, green: 0.70, blue: 0.74), dark: Color(red: 0.28, green: 0.78, blue: 0.80))
    static let cyan2 = Color.adaptive(light: Color(red: 0.13, green: 0.63, blue: 0.86), dark: Color(red: 0.30, green: 0.72, blue: 0.90))
    static let blue1 = Color.adaptive(light: Color(red: 0.20, green: 0.49, blue: 0.92), dark: Color(red: 0.38, green: 0.62, blue: 0.95))
    static let blue2 = Color.adaptive(light: Color(red: 0.30, green: 0.40, blue: 0.88), dark: Color(red: 0.45, green: 0.52, blue: 0.92))
    static let purple1 = Color.adaptive(light: Color(red: 0.50, green: 0.34, blue: 0.86), dark: Color(red: 0.60, green: 0.48, blue: 0.92))
    static let purple2 = Color.adaptive(light: Color(red: 0.69, green: 0.34, blue: 0.78), dark: Color(red: 0.78, green: 0.48, blue: 0.85))
}

private enum HomeFeatureDestination
{
    case grades
    case exams
    case nanhuRun
    case physicalTest
    case physicalCalculator
    case allCourses
    case chooseCourse
    case bus
    case electricity
    case classroom
    case strategy
    case club
    case gis
    case library
    case libraryCatalog
    case itc
    case aiAssistant
    case debug

    var authorizationScope: FeatureAuthorizationScope?
    {
        switch self
        {
        case .grades: return .grades
        case .exams: return .exams
        case .nanhuRun: return .nanhuRun
        case .physicalTest: return .physicalTest
        case .allCourses: return .allCourses
        case .chooseCourse: return .chooseCourse
        case .electricity: return .electricity
        case .library: return .libraryReservation
        case .itc: return .itc
        default: return nil
        }
    }
}

struct HomeView: View
{
    /// 每个入口各自对应一个导航开关；功能卡片的 action 只负责把相应开关设为 true。
    /// 这些状态集中在 HomeView，避免 Grid 组件和具体业务页面互相依赖。
    @State private var navigateToGrades = false
    @State private var navigateDebugRoom = false
    @State private var navigateToExams = false
    @State private var navigateToNanhuRun = false
    @State private var navigateToPhysicalTest = false
    @State private var navigateToPhysicalTestCalculator = false
    @State private var navigateToAllCoueseSearch = false
    @State private var navigateToChooseCourse = false
    @State private var navigateToBus = false
    @State private var navigateElectricity = false
    @State private var navigateToClassroom = false
    @State private var navigateToStrategy = false
    @State private var navigateToClub = false
    @State private var navigateToGIS = false
    @State private var navigateToLibrary = false
    @State private var navigateToLibraryCatalog = false
    @State private var navigateToITC = false
    @State private var navigateToAIAssistant = false
    @State private var isEditingFavorites = false
    @State private var pendingFeature: HomeFeatureDestination?
    @State private var pendingAuthorizationScope: FeatureAuthorizationScope?
    @State private var showSubscriptionSheet = false
    @State private var authorizationApproved = false
    @State private var backgroundImage: UIImage?
    /// 常用入口的选择/排序状态。必须由 @StateObject 持有，避免首页重绘时丢失编辑状态。
    @StateObject private var homeLayer = HomeLayer()

    @State private var currentTime = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @EnvironmentObject var iapStore: IAPStore
    @AppStorage("scheduleBackgroundImageFilename") private var backgroundImageFilename = ""
    @AppStorage("scheduleBackgroundOpacity") private var backgroundOpacity: Double = 0.2
    @AppStorage("scheduleContentOpacity") private var scheduleContentOpacity: Double = 1.0
    @AppStorage("homeBackgroundEnabled") private var homeBackgroundEnabled: Bool = false
    @AppStorage(PreferenceKey.showCampusPassFeatures) private var showCampusPassFeatures = true

    private var hidesCampusPassContent: Bool
    {
        !showCampusPassFeatures
    }

    var timeString: String
    {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss" // 显示 几点:几分:几秒
        return formatter.string(from: currentTime)
    }

    var dateAndWeekString: String
    {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: currentTime)
    }

    @EnvironmentObject var userinfo: userInfo

    private var isGuestMode: Bool
    {
        userinfo.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var homeCardOpacity: Double
    {
        // 文字/内容透明度独立控制；不要再用 0.9 的下限覆盖用户设置。
        scheduleContentOpacity
    }

    private var featuredFeatures: [HomeFeatureItem]
    {
        // 用 key 先恢复 HomeLayer 保存的顺序，再从全量功能中取回完整显示/跳转信息。
        let candidateMap = Dictionary(uniqueKeysWithValues: allFeatures.map { ($0.key, $0) })
        let orderedKeys = homeLayer.visiblePreferredKeys(from: allFeatures.map(\.key))

        return orderedKeys.compactMap { candidateMap[$0] }
    }

    private var allFeatures: [HomeFeatureItem]
    {
        // 首页功能的唯一入口清单：新增一个功能通常要在此定义 item，
        // 再在下方 navigationDestination 中补上目标页面。
        var items: [HomeFeatureItem] = []

        if !isGuestMode
        {
            items.append(HomeFeatureItem(key: .grades, title: "成绩查询", icon: "graduationcap.fill", color: HomeMenuColor.red1) {
                openFeature(.grades)
            })
            items.append(HomeFeatureItem(key: .exams, title: "考试查询", icon: "pencil.line", color: HomeMenuColor.orange1) {
                openFeature(.exams)
            })
            items.append(HomeFeatureItem(key: .allCourses, title: "全校课程查询", icon: "mail.and.text.magnifyingglass", color: HomeMenuColor.yellow1) {
                openFeature(.allCourses)
            })
            if !hidesCampusPassContent
            {
                items.append(HomeFeatureItem(key: .chooseCourse, title: "选课(beta)", icon: "checklist", color: HomeMenuColor.yellow2) {
                    openFeature(.chooseCourse)
                })
            }
        }

        items.append(HomeFeatureItem(key: .classroom, title: "空教室查询", icon: "door.left.hand.open", color: HomeMenuColor.green1) {
            openFeature(.classroom)
        })
        // 馆藏接口不需要校园账号，因此游客也可以使用此入口。
        items.append(HomeFeatureItem(key: .libraryCatalog, title: "馆藏检索", icon: "books.vertical.fill", color: HomeMenuColor.purple2) {
            openFeature(.libraryCatalog)
        })

        if !isGuestMode
        {
            items.append(HomeFeatureItem(key: .nanhuRun, title: "环湖跑查询", icon: "figure.run", color: HomeMenuColor.cyan1) {
                openFeature(.nanhuRun)
            })
            if !hidesCampusPassContent
            {
                items.append(HomeFeatureItem(key: .physicalTest, title: "体测查询", icon: "figure.run.square.stack.fill", color: HomeMenuColor.blue1) {
                    openFeature(.physicalTest)
                })
            }
        }

        items.append(HomeFeatureItem(key: .physicalCalculator, title: "体测计算器", icon: "plus.forwardslash.minus", color: HomeMenuColor.blue2) {
            openFeature(.physicalCalculator)
        })

        if !isGuestMode
        {
            if !hidesCampusPassContent
            {
                items.append(HomeFeatureItem(key: .itc, title: "ITC作业平台\n(beta)", icon: "chevron.left.forwardslash.chevron.right", color: HomeMenuColor.green2) {
                    openFeature(.itc)
                })
                items.append(HomeFeatureItem(key: .library, title: "图书馆预约（beta）", icon: "building.columns.fill", color: HomeMenuColor.cyan2) {
                    openFeature(.library)
                })
            }
            items.append(HomeFeatureItem(key: .electricity, title: "宿舍电费", icon: "gauge.with.needle.fill", color: HomeMenuColor.purple1) {
                openFeature(.electricity)
            })
        }

        items.append(HomeFeatureItem(key: .bus, title: "校车查询", icon: "bus", color: HomeMenuColor.red2) {
            openFeature(.bus)
        })
        items.append(HomeFeatureItem(key: .strategy, title: "攻略", icon: "info.bubble", color: HomeMenuColor.orange2) {
            openFeature(.strategy)
        })
        items.append(HomeFeatureItem(key: .club, title: "社团", icon: "person.2.fill", color: HomeMenuColor.yellow2) {
            openFeature(.club)
        })
//        items.append(HomeFeatureItem(key: .aiAssistant, title: "智学助手\n(beta)", icon: "sparkles", color: HomeMenuColor.purple2) {
//            navigateToAIAssistant = true
//        })

        #if DEBUG
        //items.append(HomeFeatureItem(key: .debug, title: "Debug", icon: "ladybug.fill", color: HomeMenuColor.purple2) {
        //    navigateDebugRoom = true
        //})
        #endif

        return items
    }

    private func loadHomeBackgroundImage()
    {
        backgroundImage = BackgroundImageStore.loadImage(named: backgroundImageFilename)
    }

    private func enterFavoriteEditing()
    {
        guard !isEditingFavorites else { return }
        isEditingFavorites = true
    }

    private func exitFavoriteEditing()
    {
        guard isEditingFavorites else { return }
        isEditingFavorites = false
    }

    private func openFeature(_ destination: HomeFeatureDestination)
    {
        guard let scope = destination.authorizationScope
        else
        {
            navigate(to: destination)
            return
        }

        pendingFeature = destination

        if scope.requiresCampusPass, !iapStore.hasActiveSubscription
        {
            showSubscriptionSheet = true
            return
        }

        presentAuthorizationIfNeeded(for: destination)
    }

    private func presentAuthorizationIfNeeded(for destination: HomeFeatureDestination)
    {
        guard let scope = destination.authorizationScope
        else
        {
            pendingFeature = nil
            navigate(to: destination)
            return
        }

        if FeatureAuthorizationStore.isAuthorized(scope, account: userinfo.username)
        {
            pendingFeature = nil
            navigate(to: destination)
        }
        else
        {
            // 先把 sheet 内容准备好，再触发展示，避免 sheet 打开时短暂出现空白页。
            pendingAuthorizationScope = scope
        }
    }

    private func handleSubscriptionDismissal()
    {
        guard let destination = pendingFeature,
              let scope = destination.authorizationScope,
              scope.requiresCampusPass
        else { return }

        if iapStore.hasActiveSubscription
        {
            presentAuthorizationIfNeeded(for: destination)
        }
        else
        {
            pendingFeature = nil
        }
    }

    private func handleAuthorizationDismissal()
    {
        guard authorizationApproved, let destination = pendingFeature
        else
        {
            authorizationApproved = false
            pendingFeature = nil
            return
        }

        authorizationApproved = false
        pendingFeature = nil
        DispatchQueue.main.async
        {
            navigate(to: destination)
        }
    }

    private func navigate(to destination: HomeFeatureDestination)
    {
        switch destination
        {
        case .grades: navigateToGrades = true
        case .exams: navigateToExams = true
        case .nanhuRun: navigateToNanhuRun = true
        case .physicalTest: navigateToPhysicalTest = true
        case .physicalCalculator: navigateToPhysicalTestCalculator = true
        case .allCourses: navigateToAllCoueseSearch = true
        case .chooseCourse: navigateToChooseCourse = true
        case .bus: navigateToBus = true
        case .electricity: navigateElectricity = true
        case .classroom: navigateToClassroom = true
        case .strategy: navigateToStrategy = true
        case .club: navigateToClub = true
        case .gis: navigateToGIS = true
        case .library: navigateToLibrary = true
        case .libraryCatalog: navigateToLibraryCatalog = true
        case .itc: navigateToITC = true
        case .aiAssistant: navigateToAIAssistant = true
        case .debug: navigateDebugRoom = true
        }
    }

    var body: some View
    {
        // MainTabView 已经为每个 Tab 提供 NavigationStack，这里直接使用它的安全区。
        ZStack
        {
            // 两个页面在同一个滚动容器内，第二层会从下方平滑接入。
            homeOverviewPage
        }
        .background
        {
            PageBackgroundView(
                image: backgroundImage,
                isEnabled: homeBackgroundEnabled,
                opacity: backgroundOpacity
            )
        }
        .navigationTitle("首页")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear
        {
            loadHomeBackgroundImage()
            // 覆盖“启动时已自动登录”的场景；已有自定义首页时该调用不会改动顺序。
            homeLayer.applyFirstLoginDefaultsIfNeeded(for: userinfo.username)
        }
        .onChange(of: backgroundImageFilename)
        { _ in
            loadHomeBackgroundImage()
        }
        .onChange(of: userinfo.username)
        { username in
            // LoginView 登录成功后会更新 username，此处立即切换首次登录的默认入口。
            homeLayer.applyFirstLoginDefaultsIfNeeded(for: username)
        }
        .sheet(isPresented: $showSubscriptionSheet, onDismiss: handleSubscriptionDismissal)
        {
            NavigationStack
            {
                SubscriptionView()
            }
        }
        .sheet(item: $pendingAuthorizationScope, onDismiss: handleAuthorizationDismissal)
        { scope in
            FeatureAuthorizationSheet(scope: scope)
            { remember in
                if remember
            {
                    FeatureAuthorizationStore.rememberAuthorization(
                        scope,
                        account: userinfo.username
                    )
                }
                authorizationApproved = true
            }
        }
        .toolbar
        {
            ToolbarItem(placement: .topBarTrailing)
            {
                Button
                {
                    if isEditingFavorites
                    {
                        exitFavoriteEditing()
                    }
                    else
                    {
                        enterFavoriteEditing()
                    }
                } label: {
                    Image(systemName: isEditingFavorites ? "checkmark.circle.fill" : "square.and.pencil")
                        .font(.system(size: 16, weight: .semibold))
                }
                .accessibilityLabel(isEditingFavorites ? "完成编辑" : "编辑常用功能")
            }
        }
        // allFeatures 中的 action 只切换状态，真正的页面路由集中在这里，便于查找和维护。
        .navigationDestination(isPresented: $navigateToGrades)
        { GradeInquiry() }
        .navigationDestination(isPresented: $navigateDebugRoom) { DebugRoom() }
        .navigationDestination(isPresented: $navigateToExams)
        { ExamView() }
        .navigationDestination(isPresented: $navigateToNanhuRun)
        { NanhuRunView() }
        .navigationDestination(isPresented: $navigateToPhysicalTest)
        { PhysicalTestView() }
        .navigationDestination(isPresented: $navigateToPhysicalTestCalculator) { PhysicalTestCalculatorView() }
        .navigationDestination(isPresented: $navigateToAllCoueseSearch)
        { AllCourseView() }
        .navigationDestination(isPresented: $navigateToChooseCourse)
        { ChooseCourseView() }
        .navigationDestination(isPresented: $navigateToBus)
        { SchoolBusView() }
        .navigationDestination(isPresented: $navigateElectricity)
        { ElectricityView() }
        .navigationDestination(isPresented: $navigateToClassroom)
        { ClassroomView() }
        .navigationDestination(isPresented: $navigateToStrategy)
        { AllStrategy() }
        .navigationDestination(isPresented: $navigateToClub)
        { AllClub() }
        .navigationDestination(isPresented: $navigateToGIS)
        { SchoolGISView() }
        .navigationDestination(isPresented: $navigateToLibrary)
        { LibraryOverviewView() }
        .navigationDestination(isPresented: $navigateToLibraryCatalog)
        { LibraryCatalogSearchView() }
        .navigationDestination(isPresented: $navigateToITC)
        { ITCView() }
        .navigationDestination(isPresented: $navigateToAIAssistant)
        { AIAssistantView() }
    }

    private var homeOverviewPage: some View
    {
        HomeStackContainer
        {
                // 第一层：收藏内容默认完整占据当前屏幕，第二层不会提前露出。
                VStack(alignment: .leading, spacing: 0)
                {
                    VStack(alignment: .leading, spacing: 8)
                    {
                        HStack(alignment: .top, spacing: 12)
                        {
                            if userinfo.showClock
                            {
                                HomeHeaderGlassCard
                                {
                                    VStack(alignment: .leading, spacing: 2)
                                    {
                                        Text(dateAndWeekString)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.secondary)

                                        Text(timeString)
                                            .font(.system(size: 22, weight: .bold, design: .rounded))
                                            .monospacedDigit()
                                    }
                                }
                                .frame(width: 168)
                                .onReceive(timer)
                                { input in
                                    currentTime = input
                                }
                            }

                            Spacer()

                            // 入学天数圆环
                            if let days = userinfo.daysSinceEnrollment, userinfo.showEnrollmentDays
                            {
                                HomeHeaderGlassCard
                                {
                                    DaysRing(days: days)
                                }
                                .frame(width: 88)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)

                        // 游客模式提示（当没有学号时显示）
                        if userinfo.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        {
                            VStack(alignment: .leading, spacing: 8)
                            {
                                Text("当前为游客模式")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)

                                Text("欢迎使用狮山有你！\n来一起探索校园生活吧！")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)

                                Text("游客模式下可使用公开信息与本地工具功能，登录后可解锁个性化校园服务。")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        }
                    }
                    .opacity(homeCardOpacity)

                    // 接下来3天事件横向滑动卡片
                    if !isGuestMode, userinfo.showNextEvent
                    {
                        VStack(alignment: .leading)
                        {
                            Text("下一个安排")
                                .font(.system(size: 24, weight: .heavy, design: .rounded))
                                .padding(16)

                            NextEventView()
                                .padding(.vertical, 4)
                        }
                        .opacity(homeCardOpacity)
                    }

                    // 首页的常用功能入口 Grid：由 HomeLayer 的偏好决定内容和顺序。
                    VStack(alignment: .leading, spacing: 14)
                    {
                        Text("常用功能")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .padding(.horizontal, 16)

                        if featuredFeatures.isEmpty
                        {
                            Text("从全部功能添加常用入口")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                        }

                        HomeFavoriteGridView(
                            features: featuredFeatures,
                            isEditing: isEditingFavorites,
                            onSelect: { feature in
                                feature.action()
                            },
                            onRemove: { feature in
                                homeLayer.remove(feature.key)
                            },
                            onStartEditing: {
                                enterFavoriteEditing()
                            },
                            onReorder: { orderedKeys in
                                homeLayer.updateVisibleOrder(orderedKeys)
                            }
                        )
                        .frame(height: HomeFavoriteGridView.height(for: featuredFeatures.count))
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 20)
                    .opacity(homeCardOpacity)

                }
            }
            allFunctionsContent:
            {
                AllFunctionView(
                    features: allFeatures,
                    homeLayer: homeLayer,
                    isEditing: $isEditingFavorites,
                    onSelect: { feature in
                        feature.action()
                    }
                )
            }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }

}

/// 首页顶部的时钟/日期和在华农天数共用同一套液态玻璃卡片规格。
/// 固定高度和内边距后，两张卡片能保持顶边、底边对齐，避免内容变化时跳动。
private struct HomeHeaderGlassCard<Content: View>: View
{
    @Environment(\.isInsideLiquidGlassSurface) private var isInsideSurface
    let content: Content
    @AppStorage(PreferenceKey.enableLiquidGlassEffect)
    private var enableLiquidGlassEffect: Bool = true
    @AppStorage(PreferenceKey.pageBackgroundOpacity)
    private var pageBackgroundOpacity: Double = 0.35
    private let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

    /// 两张首页信息卡共用固定高度，内容只负责在卡片内排版。
    static var fixedHeight: CGFloat { 72 }

    init(@ViewBuilder content: () -> Content)
    {
        self.content = content()
    }

    var body: some View
    {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .frame(height: Self.fixedHeight, alignment: .center)
            .frame(maxWidth: .infinity)
            .environment(
                \.isInsideLiquidGlassSurface,
                isInsideSurface || (enableLiquidGlassEffect && LiquidGlassAvailability.isSupported)
            )
            .background
            {
                shape
                    .fill(.ultraThinMaterial)
                    .opacity(min(max(pageBackgroundOpacity * 0.7, 0.12), 0.28))
                    .optionalLiquidGlass(enabled: enableLiquidGlassEffect, in: shape)
            }
            .clipShape(shape)
    }
}


struct MenuGridItem: View
{
    @AppStorage(PreferenceKey.pageBackgroundOpacity) private var pageBackgroundOpacity: Double = 0.35

    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View
    {
        Button(action: action)
        {
            VStack(spacing: 12)
            {
                ZStack
                {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        // 默认 35% 时保持原来的图标底色；调低页面背景不透明度
                        // 时，常用功能卡片也会同步更通透。
                        .fill(color.opacity(0.18 * min(max(pageBackgroundOpacity / 0.35, 0), 1)))
                        .frame(width: 60, height: 60)
                        .optionalLiquidGlass(allowsNesting: true, cornerRadius: 16)

                    Image(systemName: icon)
                        .font(.system(size: 26))
                        .foregroundColor(color)
                }

                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 入学天数圆环

private struct DaysRing: View
{
    let days: Int

    var body: some View
    {
        ZStack
        {
            // 底环
            Circle()
                .stroke(Color.green.opacity(0.15), lineWidth: 4)
                .frame(width: 48, height: 48)

            // 进度环（按一年365天算比例）
            Circle()
                .trim(from: 0, to: min(CGFloat(days) / 365, 1.0))
                .stroke(
                    Color.green.opacity(0.6),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 48, height: 48)
                .rotationEffect(.degrees(-90))

            // 中间数字 + 文字
            VStack(spacing: 1)
            {
                Text(String(days))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.primary)

                Text("天")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview
{
    HomeView()
        .environmentObject(userInfo())
        .environmentObject(IAPStore.preview(hasActiveSubscription: false))
}
