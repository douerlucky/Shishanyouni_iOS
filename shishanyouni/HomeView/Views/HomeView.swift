import Combine
import SwiftUI
import UIKit

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

    private func selectFeature(_ feature: HomeFeatureItem)
    {
        guard !isEditingFavorites else { return }
        feature.action()
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
                .accessibilityLabel(isEditingFavorites ? "完成编辑" : "编辑功能入口")
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
                                            .appTextOpacity()

                                        Text(timeString)
                                            .font(.system(size: 22, weight: .bold, design: .rounded))
                                            .monospacedDigit()
                                            .appTextOpacity()
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
                            .appTextOpacity()
                        }
                    }

                    // 接下来3天事件横向滑动卡片
                    if !isGuestMode, userinfo.showNextEvent
                    {
                        VStack(alignment: .leading)
                        {
                            Text("下一个安排")
                                .font(.system(size: 24, weight: .heavy, design: .rounded))
                                .padding(16)
                                .appTextOpacity()

                            NextEventView()
                                .padding(.vertical, 4)
                        }
                    }

                    // 首页的常用功能入口 Grid：由 HomeLayer 的偏好决定内容和顺序。
                    VStack(alignment: .leading, spacing: 14)
                    {
                        Text("常用功能")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .padding(.horizontal, 16)
                            .appTextOpacity()

                        if featuredFeatures.isEmpty
                        {
                            Text("从全部功能添加常用入口")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                                .appTextOpacity()
                        }

                        HomeFeatureGridView(
                            features: featuredFeatures,
                            isEditing: isEditingFavorites,
                            onSelect: selectFeature,
                            onAccessory: { feature in
                                homeLayer.remove(feature.key)
                            },
                            onStartEditing: {
                                enterFavoriteEditing()
                            },
                            onReorder: { orderedKeys in
                                homeLayer.updateVisibleOrder(orderedKeys)
                            }
                        )
                        .frame(height: HomeFeatureGridView.height(for: featuredFeatures.count))
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 20)

                }
            }
            allFunctionsContent:
            {
                AllFunctionView(
                    features: allFeatures,
                    homeLayer: homeLayer,
                    isEditing: $isEditingFavorites,
                    onSelect: selectFeature
                )
            }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }

}
