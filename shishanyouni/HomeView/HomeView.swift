import SwiftUI
import UIKit

// 首页职责：
// 1. 在 allFeatures 定义所有入口及其跳转动作；
// 2. 通过 HomeLayer 选出首页常用入口；
// 3. 用 HomeVerticalPager 在“首页概览”和“全部功能”之间上下翻页。

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
    @State private var navigateToITC = false
    @State private var navigateToAIAssistant = false
    @State private var navigateToSubscription = false
    /// 0 是首页概览，1 是全部功能页；编辑常用入口时会锁住翻页，避免手势冲突。
    @State private var currentPage = 0
    @State private var isEditingFavorites = false
    @State private var backgroundImage: UIImage?
    /// 常用入口的选择/排序状态。必须由 @StateObject 持有，避免首页重绘时丢失编辑状态。
    @StateObject private var homeLayer = HomeLayer()

    @State private var currentTime = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @EnvironmentObject var iapStore: IAPStore

    @AppStorage("scheduleBackgroundImageFilename") private var backgroundImageFilename = ""
    @AppStorage("scheduleBackgroundOpacity") private var backgroundOpacity: Double = 0.2
    @AppStorage("scheduleContentOpacity") private var scheduleContentOpacity: Double = 1.0
    @AppStorage("enableLiquidGlassEffect") private var enableLiquidGlassEffect: Bool = false
    @AppStorage("homeBackgroundEnabled") private var homeBackgroundEnabled: Bool = false

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
        max(scheduleContentOpacity, 0.9)
    }

    /// 旧的 SwiftUI Grid 配置；当前首页实际使用的是 HomeFavoriteGridView（UICollectionView）。
    /// 保留它不影响功能，但它不是控制首页入口布局的地方。
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

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
                navigateToGrades = true
            })
            items.append(HomeFeatureItem(key: .exams, title: "考试查询", icon: "pencil.line", color: HomeMenuColor.orange1) {
                navigateToExams = true
            })
            items.append(HomeFeatureItem(key: .allCourses, title: "全校课程查询", icon: "mail.and.text.magnifyingglass", color: HomeMenuColor.yellow1) {
                navigateToAllCoueseSearch = true
            })
            items.append(HomeFeatureItem(key: .chooseCourse, title: "选课(beta)", icon: "checklist", color: HomeMenuColor.yellow2) {
                // 选课会实际向教务系统提交选、退课请求，纳入校园通行证权益保护。
                // 页面自身也会再次检查权限，避免从其它入口直达时绕过这里。
                if iapStore.hasActiveSubscription
                {
                    navigateToChooseCourse = true
                }
                else
                {
                    navigateToSubscription = true
                }
            })
        }

        items.append(HomeFeatureItem(key: .classroom, title: "空教室查询", icon: "door.left.hand.open", color: HomeMenuColor.green1) {
            navigateToClassroom = true
        })

        if !isGuestMode
        {
            items.append(HomeFeatureItem(key: .nanhuRun, title: "环湖跑查询", icon: "figure.run", color: HomeMenuColor.cyan1) {
                navigateToNanhuRun = true
            })
            items.append(HomeFeatureItem(key: .physicalTest, title: "体测查询", icon: "figure.run.square.stack.fill", color: HomeMenuColor.blue1) {
                if iapStore.hasActiveSubscription
                {
                    navigateToPhysicalTest = true
                }
                else
                {
                    navigateToSubscription = true
                }
            })
        }

        items.append(HomeFeatureItem(key: .physicalCalculator, title: "体测计算器", icon: "plus.forwardslash.minus", color: HomeMenuColor.blue2) {
            navigateToPhysicalTestCalculator = true
        })

        if !isGuestMode
        {
            items.append(HomeFeatureItem(key: .itc, title: "信息学院ITC平台 \n(beta)", icon: "chevron.left.forwardslash.chevron.right", color: HomeMenuColor.green2) {
                if iapStore.hasActiveSubscription
                {
                    navigateToITC = true
                }
                else
                {
                    navigateToSubscription = true
                }
            })
            items.append(HomeFeatureItem(key: .library, title: "图书馆预约（beta）", icon: "building.columns.fill", color: HomeMenuColor.cyan2) {
                if iapStore.hasActiveSubscription
                {
                    navigateToLibrary = true
                }
                else
                {
                    navigateToSubscription = true
                }
            })
            items.append(HomeFeatureItem(key: .electricity, title: "宿舍电费", icon: "gauge.with.needle.fill", color: HomeMenuColor.purple1) {
                navigateElectricity = true
            })
        }

        items.append(HomeFeatureItem(key: .bus, title: "校车查询", icon: "bus", color: HomeMenuColor.red2) {
            navigateToBus = true
        })
        items.append(HomeFeatureItem(key: .strategy, title: "攻略", icon: "info.bubble", color: HomeMenuColor.orange2) {
            navigateToStrategy = true
        })
        items.append(HomeFeatureItem(key: .club, title: "社团", icon: "person.2.fill", color: HomeMenuColor.yellow2) {
            navigateToClub = true
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
        guard !backgroundImageFilename.isEmpty
        else
        {
            backgroundImage = nil
            return
        }

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(backgroundImageFilename)

        if let data = try? Data(contentsOf: documentsURL),
           let image = UIImage(data: data)
        {
            backgroundImage = image
            return
        }

        if let sharedURL = CurriculumWidgetSync.appGroupContainerURL()?.appendingPathComponent(backgroundImageFilename),
           let data = try? Data(contentsOf: sharedURL),
           let image = UIImage(data: data)
        {
            backgroundImage = image
            return
        }

        backgroundImage = nil
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

    var body: some View
    {
        NavigationStack
        {
            ZStack
            {
                Color(uiColor: .systemGroupedBackground)
                    .opacity(homeBackgroundEnabled ? 0 : 1)
                    .ignoresSafeArea()

                if homeBackgroundEnabled, let backgroundImage
                {
                    Image(uiImage: backgroundImage)
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                        .opacity(backgroundOpacity)
                }

                // 两页共用同一份 allFeatures 和 HomeLayer，因此“添加到首页”会立即反映在第一页。
                HomeVerticalPager(currentPage: $currentPage, isPagingLocked: isEditingFavorites, pages: [
                    AnyView(homeOverviewPage),
                    AnyView(
                        AllFunctionView(
                            features: allFeatures,
                            homeLayer: homeLayer,
                            isEditing: $isEditingFavorites,
                            onBack: { currentPage = 0 },
                            onSelect: { feature in
                                currentPage = 0
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15)
                                {
                                    feature.action()
                                }
                            }
                        )
                    )
                ])
            }
            .navigationTitle("首页")
            .navigationBarTitleDisplayMode(.inline)
            .ignoresSafeArea(edges: .bottom)
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
            .navigationDestination(isPresented: $navigateToGrades) { GradeInquiry() }
            .navigationDestination(isPresented: $navigateDebugRoom) { DebugRoom() }
            .navigationDestination(isPresented: $navigateToExams) { ExamView() }
            .navigationDestination(isPresented: $navigateToNanhuRun) { NanhuRunView() }
            .navigationDestination(isPresented: $navigateToPhysicalTest) { PhysicalTestView() }
            .navigationDestination(isPresented: $navigateToSubscription) { SubscriptionView() }
            .navigationDestination(isPresented: $navigateToPhysicalTestCalculator) { PhysicalTestCalculatorView() }
            .navigationDestination(isPresented: $navigateToAllCoueseSearch) { AllCourseView() }
            .navigationDestination(isPresented: $navigateToChooseCourse) { ChooseCourseView() }
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
            .navigationDestination(isPresented: $navigateToITC)
            { ITCView() }
            .navigationDestination(isPresented: $navigateToAIAssistant)
            { AIAssistantView() }
        }
    }

    private var homeOverviewPage: some View
    {
        GeometryReader
        {
            proxy in
            ScrollView
            {
                VStack(alignment: .leading, spacing: 0)
                {
                    VStack(alignment: .leading, spacing: 8)
                    {
                        HStack(alignment: .center)
                        {
                            if userinfo.showClock
                            {
                                VStack(alignment: .leading, spacing: 2)
                                {
                                    Text(dateAndWeekString)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.secondary)

                                    Text(timeString)
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .monospacedDigit()
                                }
                                .onReceive(timer)
                                { input in
                                    currentTime = input
                                }
                            }

                            Spacer()

                            // 入学天数圆环
                            if let days = userinfo.daysSinceEnrollment, userinfo.showEnrollmentDays
                            {
                                VStack(spacing: 3)
                                {
                                    DaysRing(days: days)
                                    Text("在华农天数")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
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

                                Text("欢迎使用狮山有你！\n来一起探索华中农业大学吧！")
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
                                .font(.system(size: 17, weight: .bold))
                                .padding(.horizontal, 16)
                            NextEventView()
                                .padding(.vertical, 4)
                        }
                        .opacity(homeCardOpacity)
                    }

                    // 首页的常用功能入口 Grid：由 HomeLayer 的偏好决定内容和顺序。
                    VStack(alignment: .leading, spacing: 14)
                    {
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
                    .opacity(homeCardOpacity)

                    Spacer(minLength: 20)

                    HomeFloatingPagerButton(direction: "chevron.down", enableLiquidGlassEffect: enableLiquidGlassEffect)
                        .frame(maxWidth: .infinity)
                        .onTapGesture
                    {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        currentPage = 1
                    }
                        .padding(.bottom, 24)
                }
                .frame(minHeight: proxy.size.height, alignment: .top)
            }
            .scrollIndicators(.hidden)
        }
        .background(Color.clear)
    }
}

struct HomeFloatingPagerButton: View
{
    let direction: String
    let enableLiquidGlassEffect: Bool

    var body: some View
    {
        Image(systemName: direction)
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.blue)
            .frame(width: 32, height: 32)
            .background(Color(.systemBackground).opacity(0.5))
            .clipShape(Circle())
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            .optionalLiquidGlass(enabled: enableLiquidGlassEffect)
    }
}

/// 使用 UIPageViewController 做纵向分页。
/// SwiftUI 没有直接等价的纵向分页组件；编辑常用功能时会禁用其内部滚动，
/// 防止长按拖拽与页面翻动抢手势。
private struct HomeVerticalPager: UIViewControllerRepresentable
{
    @Binding var currentPage: Int
    let isPagingLocked: Bool
    let pages: [AnyView]

    func makeCoordinator() -> Coordinator
    {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController
    {
        let controller = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .vertical
        )
        controller.view.backgroundColor = .clear

        // 每个 SwiftUI 页面放进一个 UIHostingController，交给 UIKit 分页控制器管理。
        let viewControllers = pages.map
        {
            let hostingController = UIHostingController(rootView: $0)
            hostingController.view.backgroundColor = .clear
            return hostingController
        }
        context.coordinator.controllers = viewControllers

        if let first = viewControllers.first
        {
            controller.setViewControllers([first], direction: .forward, animated: false)
        }

        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        context.coordinator.setPagingEnabled(!isPagingLocked, in: controller)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIPageViewController, context: Context)
    {
        context.coordinator.parent = self
        context.coordinator.updatePages(pages)
        context.coordinator.setPagingEnabled(!isPagingLocked, in: uiViewController)

        guard context.coordinator.controllers.indices.contains(currentPage) else { return }
        guard context.coordinator.visibleIndex != currentPage else { return }

        let direction: UIPageViewController.NavigationDirection = currentPage >= context.coordinator.visibleIndex ? .forward : .reverse
        context.coordinator.visibleIndex = currentPage
        uiViewController.setViewControllers(
            [context.coordinator.controllers[currentPage]],
            direction: direction,
            animated: true
        )
    }

    /// 维护 UIKit 页面控制器与 SwiftUI 的 currentPage 双向同步。
    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate
    {
        var parent: HomeVerticalPager
        var controllers: [UIHostingController<AnyView>] = []
        var visibleIndex = 0
        private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

        init(_ parent: HomeVerticalPager)
        {
            self.parent = parent
            super.init()
            feedbackGenerator.prepare()
        }

        func updatePages(_ pages: [AnyView])
        {
            guard controllers.count == pages.count else { return }

            for (index, page) in pages.enumerated()
            {
                controllers[index].rootView = page
                controllers[index].view.backgroundColor = .clear
            }
        }

        func setPagingEnabled(_ isEnabled: Bool, in pageViewController: UIPageViewController)
        {
            pageViewController.view.subviews.compactMap { $0 as? UIScrollView }.forEach
            {
                $0.isScrollEnabled = isEnabled
            }
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController?
        {
            guard let index = controllers.firstIndex(where: { $0 === viewController }), index > 0 else { return nil }
            return controllers[index - 1]
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController?
        {
            guard let index = controllers.firstIndex(where: { $0 === viewController }), index + 1 < controllers.count else { return nil }
            return controllers[index + 1]
        }

        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool)
        {
            guard completed,
                  let currentController = pageViewController.viewControllers?.first,
                  let index = controllers.firstIndex(where: { $0 === currentController })
            else { return }

            visibleIndex = index
            parent.currentPage = index
            feedbackGenerator.impactOccurred()
            feedbackGenerator.prepare()
        }
    }
}

struct MenuGridItem: View
{
    @AppStorage("enableLiquidGlassEffect") private var enableLiquidGlassEffect: Bool = false

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
                        .fill(color.opacity(0.18))
                        .frame(width: 60, height: 60)
                        .optionalLiquidGlass(enabled: enableLiquidGlassEffect, cornerRadius: 16)

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
                .frame(width: 60, height: 60)

            // 进度环（按一年365天算比例）
            Circle()
                .trim(from: 0, to: min(CGFloat(days) / 365, 1.0))
                .stroke(
                    Color.green.opacity(0.6),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 60, height: 60)
                .rotationEffect(.degrees(-90))

            // 中间数字 + 文字
            VStack(spacing: 1)
            {
                Text("\(days)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
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
