import SwiftUI
import UIKit

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
    @State private var navigateToGrades = false
    @State private var navigateDebugRoom = false
    @State private var navigateToExams = false
    @State private var navigateToNanhuRun = false
    @State private var navigateToPhysicalTest = false
    @State private var navigateToPhysicalTestCalculator = false
    @State private var navigateToAllCoueseSearch = false
    @State private var navigateToBus = false
    @State private var navigateElectricity = false
    @State private var navigateToClassroom = false
    @State private var navigateToStrategy = false
    @State private var navigateToClub = false
    @State private var navigateToGIS = false
    @State private var navigateToLibrary = false
    @State private var navigateToITC = false
    @State private var navigateToSubscription = false
    @State private var currentPage = 0
    @State private var isEditingFavorites = false
    @State private var backgroundImage: UIImage?
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

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    private var featuredFeatures: [HomeFeatureItem]
    {
        let candidateMap = Dictionary(uniqueKeysWithValues: allFeatures.map { ($0.key, $0) })
        let orderedKeys = homeLayer.visiblePreferredKeys(from: allFeatures.map(\.key))

        return orderedKeys.compactMap { candidateMap[$0] }
    }

    private var allFeatures: [HomeFeatureItem]
    {
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

        if let sharedURL = WidgetSharedStore.sharedContainerURL()?.appendingPathComponent(backgroundImageFilename),
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
            }
            .onChange(of: backgroundImageFilename)
            { _ in
                loadHomeBackgroundImage()
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
            .navigationDestination(isPresented: $navigateToGrades) { GradeInquiry() }
            .navigationDestination(isPresented: $navigateDebugRoom) { DebugRoom() }
            .navigationDestination(isPresented: $navigateToExams) { ExamView() }
            .navigationDestination(isPresented: $navigateToNanhuRun) { NanhuRunView() }
            .navigationDestination(isPresented: $navigateToPhysicalTest) { PhysicalTestView() }
            .navigationDestination(isPresented: $navigateToSubscription) { SubscriptionView() }
            .navigationDestination(isPresented: $navigateToPhysicalTestCalculator) { PhysicalTestCalculatorView() }
            .navigationDestination(isPresented: $navigateToAllCoueseSearch) { AllCourseView() }
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
