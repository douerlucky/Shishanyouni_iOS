import SwiftUI
import UIKit

// 首页功能入口的数据流：
// HomeView.allFeatures（所有可用功能）
//   -> HomeLayer.preferredKeys（用户选择/排序，持久化）
//   -> HomeView.featuredFeatures（当前首页可见项）
//   -> HomeFavoriteGridView（首页的可编辑三列 Grid）

/// 用于保存首页入口偏好和连接路由的稳定 ID。
/// rawValue 已写入 UserDefaults，改名会让旧用户的首页配置失效。
enum HomeFeatureKey: String, CaseIterable, Codable, Identifiable
{
    case grades
    case exams
    case allCourses
    case chooseCourse
    case classroom
    case nanhuRun
    case physicalTest
    case physicalCalculator
    case itc
    case library
    case electricity
    case bus
    case strategy
    case club
    case aiAssistant
    case debug

    var id: String { rawValue }
}

/// 一个实际可展示、可点击的首页入口。
/// `action` 由 HomeView 创建，通常只是切换对应的导航状态。
struct HomeFeatureItem: Identifiable
{
    let key: HomeFeatureKey
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var id: HomeFeatureKey { key }
}

/// 管理“主页常用功能”的选择和排序，并将结果保存到 UserDefaults。
/// 它只存 key，不存标题/图标，避免展示配置与业务入口定义分散。
final class HomeLayer: ObservableObject
{
    /// 当前用户选中的功能及顺序；@Published 会驱动首页 Grid 自动更新。
    @Published private(set) var preferredKeys: [HomeFeatureKey]

    /// 只存用户选择；所有功能详情仍以 HomeView.allFeatures 为唯一来源。
    private static let storageKey = "home_preferred_feature_keys"
    /// 首次安装、尚无本地配置时显示的默认常用功能。
    private static let guestDefaultKeys: [HomeFeatureKey] = [
        .classroom,
        .physicalCalculator,
        .bus,
        .strategy,
        .club
    ]
    /// 学生首次登录后展示的常用入口，按首页从左到右、从上到下的顺序排列。
    private static let firstLoginDefaultKeys: [HomeFeatureKey] = [
        .grades,
        .exams,
        .classroom,
        .nanhuRun,
        .bus,
        .strategy,
        .club
    ]

    private let defaults: UserDefaults
    /// 只要用户调整过首页（包括清空全部入口），就不再用首次登录默认值覆盖。
    private var hasSavedPreference = false

    init(defaults: UserDefaults = .standard)
    {
        self.defaults = defaults

        // 优先恢复用户上一次编辑结果；解码失败或首次进入时才使用默认入口。
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([HomeFeatureKey].self, from: data)
        {
            preferredKeys = decoded
            hasSavedPreference = true
        }
        else
        {
            preferredKeys = Self.guestDefaultKeys
        }
    }

    /// 登录成功后，为尚未配置过首页的用户设置登录版默认入口。
    ///
    /// 游客主动增删或排序过入口、以及旧用户已有的持久化配置都会被保留；
    /// 因此这个方法可以在 `onAppear` 和登录状态变化时安全地重复调用。
    func applyFirstLoginDefaultsIfNeeded(for username: String)
    {
        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !hasSavedPreference
        else { return }

        preferredKeys = Self.firstLoginDefaultKeys
        save()
    }

    /// 全部功能页用它判断该入口是否已经在首页，从而决定是否显示加号。
    func contains(_ key: HomeFeatureKey) -> Bool
    {
        preferredKeys.contains(key)
    }

    /// 将入口追加到首页末尾；重复添加会被忽略。
    func add(_ key: HomeFeatureKey)
    {
        guard !preferredKeys.contains(key) else { return }
        preferredKeys.append(key)
        save()
    }

    /// 从首页移除入口，但不会影响“全部功能”目录本身。
    func remove(_ key: HomeFeatureKey)
    {
        preferredKeys.removeAll { $0 == key }
        save()
    }

    /// 按 key 调整顺序的通用接口；当前拖拽 Grid 使用 updateVisibleOrder 批量回传顺序。
    func move(_ sourceKey: HomeFeatureKey, before targetKey: HomeFeatureKey)
    {
        guard sourceKey != targetKey,
              let sourceIndex = preferredKeys.firstIndex(of: sourceKey),
              let targetIndex = preferredKeys.firstIndex(of: targetKey)
        else { return }

        let moved = preferredKeys.remove(at: sourceIndex)
        let adjustedTarget = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
        preferredKeys.insert(moved, at: adjustedTarget)
        save()
    }

    func updateVisibleOrder(_ visibleKeys: [HomeFeatureKey])
    {
        // 游客模式会暂时隐藏部分功能；排序时保留这些不可见 key，登录后仍能恢复。
        let visibleSet = Set(visibleKeys)
        let hiddenKeys = preferredKeys.filter { !visibleSet.contains($0) }
        preferredKeys = visibleKeys + hiddenKeys
        save()
    }

    /// 只返回当前模式可用的入口；例如游客模式会隐藏成绩、考试等登录功能。
    func visiblePreferredKeys(from availableKeys: [HomeFeatureKey]) -> [HomeFeatureKey]
    {
        let allowed = Set(availableKeys)
        return preferredKeys.filter { allowed.contains($0) }
    }

    private func save()
    {
        if let data = try? JSONEncoder().encode(preferredKeys)
        {
            defaults.set(data, forKey: Self.storageKey)
            hasSavedPreference = true
        }
    }
}

/// 全部功能页使用的 SwiftUI 图标单元：可点击、可长按进入编辑，并可显示加号。
struct EditableHomeFeatureItem: View
{
    let feature: HomeFeatureItem
    let isEditing: Bool
    let accessoryIcon: String?
    let accessoryColor: Color
    let action: () -> Void
    let accessoryAction: (() -> Void)?
    let onLongPress: (() -> Void)?

    var body: some View
    {
        let item = ZStack(alignment: .topTrailing)
        {
            MenuGridItem(title: feature.title, icon: feature.icon, color: feature.color, action: action)

            if let accessoryIcon, isEditing, let accessoryAction
            {
                Button(action: accessoryAction)
                {
                    Image(systemName: accessoryIcon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(accessoryColor)
                        .background(
                            Circle()
                                .fill(Color(uiColor: .systemBackground))
                                .frame(width: 22, height: 22)
                        )
                }
                .buttonStyle(.plain)
                .offset(x: -2, y: -6)
            }
        }
        .contentShape(Rectangle())

        if let onLongPress
        {
            item.simultaneousGesture(
                LongPressGesture(minimumDuration: 0.45)
                    .onEnded { _ in
                        onLongPress()
                    }
            )
        }
        else
        {
            item
        }
    }
}

private struct HomeFeatureGlassIcon: View
{
    let icon: String
    let color: Color
    let glassEnabled: Bool

    var body: some View
    {
        ZStack
        {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(color.opacity(0.18))
                .frame(width: 60, height: 60)
                .optionalLiquidGlass(enabled: glassEnabled, cornerRadius: 16)

            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundColor(color)
        }
        .frame(width: 60, height: 60)
    }
}

/// 首页真正的“常用功能”Grid。
///
/// 这里特意用 UICollectionView 包装，而不是 LazyVGrid：iOS 原生的交互式移动
/// 能稳定支持长按、拖拽排序和删除按钮。HomeView 负责传数据和回调，Coordinator
/// 负责把 UIKit 的事件翻译回 SwiftUI/HomeLayer。
struct HomeFavoriteGridView: UIViewRepresentable
{
    let features: [HomeFeatureItem]
    let isEditing: Bool
    let onSelect: (HomeFeatureItem) -> Void
    let onRemove: (HomeFeatureItem) -> Void
    let onStartEditing: () -> Void
    let onReorder: ([HomeFeatureKey]) -> Void

    static func height(for count: Int) -> CGFloat
    {
        // UICollectionView 本身不滚动，外层需要根据三列布局预先给出精确高度。
        guard count > 0 else { return 0 }

        let rows = max(1, Int(ceil(Double(count) / 3.0)))
        return 10 + CGFloat(rows) * 110 + CGFloat(max(0, rows - 1)) * 20
    }

    func makeCoordinator() -> Coordinator
    {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UICollectionView
    {
        // Grid 的视觉规格：三列、每格 110pt 高、行距 20pt。
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 20
        layout.sectionInset = UIEdgeInsets(top: 10, left: 0, bottom: 0, right: 0)

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.clipsToBounds = false
        collectionView.isScrollEnabled = false
        collectionView.alwaysBounceVertical = false
        collectionView.dragInteractionEnabled = false
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        collectionView.register(HomeFavoriteCell.self, forCellWithReuseIdentifier: Coordinator.cellIdentifier)

        // UIKit 的 interactive movement 由长按手势启动，SwiftUI 的 Grid 没有同等能力。
        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.35
        longPress.cancelsTouchesInView = true
        collectionView.addGestureRecognizer(longPress)
        context.coordinator.collectionView = collectionView

        return collectionView
    }

    func updateUIView(_ collectionView: UICollectionView, context: Context)
    {
        context.coordinator.parent = self
        context.coordinator.currentFeatures = features

        // 拖动中 reloadData 会中断手势，因此只在非拖动状态刷新数据。
        if !context.coordinator.isInteractivelyMoving
        {
            collectionView.reloadData()
        }
    }

    /// UICollectionView 的 data source、点击、删除和拖拽事件中转层。
    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout
    {
        static let cellIdentifier = "HomeFavoriteGridCell"

        var parent: HomeFavoriteGridView
        var currentFeatures: [HomeFeatureItem]
        weak var collectionView: UICollectionView?
        private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        var isInteractivelyMoving = false

        init(parent: HomeFavoriteGridView)
        {
            self.parent = parent
            currentFeatures = parent.features
            super.init()
            feedbackGenerator.prepare()
        }

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
        {
            currentFeatures.count
        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
        {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Self.cellIdentifier, for: indexPath) as? HomeFavoriteCell
            else { return UICollectionViewCell() }

            let feature = currentFeatures[indexPath.item]

            cell.configure(
                feature: feature,
                isEditing: parent.isEditing,
                canRemove: true
            ) {
                self.parent.onRemove(feature)
            }

            return cell
        }

        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
        {
            guard !parent.isEditing, currentFeatures.indices.contains(indexPath.item) else { return }
            parent.onSelect(currentFeatures[indexPath.item])
        }

        func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool
        {
            currentFeatures.count > 1
        }

        func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath)
        {
            guard currentFeatures.indices.contains(sourceIndexPath.item),
                  currentFeatures.indices.contains(destinationIndexPath.item)
            else { return }

            let moved = currentFeatures.remove(at: sourceIndexPath.item)
            currentFeatures.insert(moved, at: destinationIndexPath.item)
            // 不直接写 UserDefaults；交给 HomeLayer 统一处理排序和持久化。
            parent.onReorder(currentFeatures.map(\.key))
        }

        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize
        {
            let width = floor(collectionView.bounds.width / 3)
            return CGSize(width: width, height: 110)
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer)
        {
            guard let collectionView, currentFeatures.count > 1 else { return }

            let location = gesture.location(in: collectionView)

            switch gesture.state
            {
            case .began:
                guard let indexPath = collectionView.indexPathForItem(at: location) else { return }
                isInteractivelyMoving = true
                if !parent.isEditing
                {
                    parent.onStartEditing()
                    collectionView.visibleCells.compactMap { $0 as? HomeFavoriteCell }.forEach { $0.setEditing(true) }
                    feedbackGenerator.impactOccurred()
                    feedbackGenerator.prepare()
                }
                // 开始原生拖拽；结束时 UICollectionView 会回调 moveItemAt。
                collectionView.beginInteractiveMovementForItem(at: indexPath)
            case .changed:
                collectionView.updateInteractiveMovementTargetPosition(location)
            case .ended:
                collectionView.endInteractiveMovement()
                isInteractivelyMoving = false
                collectionView.reloadData()
            default:
                collectionView.cancelInteractiveMovement()
                isInteractivelyMoving = false
                collectionView.reloadData()
            }
        }
    }

    /// UIKit Cell 内嵌一个 SwiftUI 图标视图，保留现有的液态玻璃绘制效果。
    final class HomeFavoriteCell: UICollectionViewCell
    {
        private let iconHostContainer = UIView()
        private var iconHostingController: UIHostingController<AnyView>?
        private let titleLabel = UILabel()
        private let accessoryButton = UIButton(type: .system)
        private var accessoryAction: (() -> Void)?

        override init(frame: CGRect)
        {
            super.init(frame: frame)
            setup()
        }

        required init?(coder: NSCoder)
        {
            super.init(coder: coder)
            setup()
        }

        override func prepareForReuse()
        {
            super.prepareForReuse()
            accessoryAction = nil
            accessoryButton.isHidden = true
        }

        func configure(feature: HomeFeatureItem, isEditing: Bool, canRemove: Bool, accessoryAction: @escaping () -> Void)
        {
            let glassEnabled = UserDefaults.standard.bool(forKey: "enableLiquidGlassEffect")

            updateIcon(icon: feature.icon, color: feature.color, glassEnabled: glassEnabled)
            titleLabel.text = feature.title
            self.accessoryAction = accessoryAction

            accessoryButton.isHidden = !(isEditing && canRemove)
        }

        func setEditing(_ isEditing: Bool)
        {
            accessoryButton.isHidden = !isEditing
        }

        private func setup()
        {
            backgroundColor = .clear
            clipsToBounds = false
            contentView.backgroundColor = .clear
            contentView.clipsToBounds = false

            iconHostContainer.translatesAutoresizingMaskIntoConstraints = false
            iconHostContainer.backgroundColor = .clear
            iconHostContainer.isUserInteractionEnabled = false

            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
            titleLabel.textColor = .label
            titleLabel.textAlignment = .center
            titleLabel.numberOfLines = 2

            accessoryButton.translatesAutoresizingMaskIntoConstraints = false
            accessoryButton.setImage(UIImage(systemName: "minus.circle.fill"), for: .normal)
            accessoryButton.tintColor = .systemRed
            accessoryButton.backgroundColor = .systemBackground
            accessoryButton.layer.cornerRadius = 11
            accessoryButton.layer.masksToBounds = true
            accessoryButton.isHidden = true
            accessoryButton.addTarget(self, action: #selector(didTapAccessory), for: .touchUpInside)

            contentView.addSubview(iconHostContainer)
            contentView.addSubview(titleLabel)
            contentView.addSubview(accessoryButton)

            NSLayoutConstraint.activate([
                iconHostContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
                iconHostContainer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                iconHostContainer.widthAnchor.constraint(equalToConstant: 60),
                iconHostContainer.heightAnchor.constraint(equalToConstant: 60),

                titleLabel.topAnchor.constraint(equalTo: iconHostContainer.bottomAnchor, constant: 12),
                titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
                titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),

                accessoryButton.topAnchor.constraint(equalTo: iconHostContainer.topAnchor, constant: -4),
                accessoryButton.trailingAnchor.constraint(equalTo: iconHostContainer.trailingAnchor, constant: 4),
                accessoryButton.widthAnchor.constraint(equalToConstant: 22),
                accessoryButton.heightAnchor.constraint(equalToConstant: 22)
            ])
        }

        private func updateIcon(icon: String, color: Color, glassEnabled: Bool)
        {
            let view = AnyView(HomeFeatureGlassIcon(icon: icon, color: color, glassEnabled: glassEnabled))

            if let iconHostingController
            {
                iconHostingController.rootView = view
                return
            }

            let hostingController = UIHostingController(rootView: view)
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            hostingController.view.backgroundColor = .clear
            hostingController.view.isUserInteractionEnabled = false
            iconHostContainer.addSubview(hostingController.view)

            NSLayoutConstraint.activate([
                hostingController.view.topAnchor.constraint(equalTo: iconHostContainer.topAnchor),
                hostingController.view.leadingAnchor.constraint(equalTo: iconHostContainer.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: iconHostContainer.trailingAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: iconHostContainer.bottomAnchor)
            ])

            iconHostingController = hostingController
        }

        @objc private func didTapAccessory()
        {
            accessoryAction?()
        }
    }
}
