import SwiftUI
import UIKit

enum HomeFeatureKey: String, CaseIterable, Codable, Identifiable
{
    case grades
    case exams
    case allCourses
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

struct HomeFeatureItem: Identifiable
{
    let key: HomeFeatureKey
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var id: HomeFeatureKey { key }
}

final class HomeLayer: ObservableObject
{
    @Published private(set) var preferredKeys: [HomeFeatureKey]

    private let storageKey = "home_preferred_feature_keys"
    private let defaultKeys: [HomeFeatureKey] = [
        .classroom,
        .physicalCalculator,
        .bus,
        .strategy,
        .club
    ]

    init()
    {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([HomeFeatureKey].self, from: data)
        {
            preferredKeys = decoded
        }
        else
        {
            preferredKeys = defaultKeys
        }
    }

    func contains(_ key: HomeFeatureKey) -> Bool
    {
        preferredKeys.contains(key)
    }

    func add(_ key: HomeFeatureKey)
    {
        guard !preferredKeys.contains(key) else { return }
        preferredKeys.append(key)
        save()
    }

    func remove(_ key: HomeFeatureKey)
    {
        preferredKeys.removeAll { $0 == key }
        save()
    }

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
        let visibleSet = Set(visibleKeys)
        let hiddenKeys = preferredKeys.filter { !visibleSet.contains($0) }
        preferredKeys = visibleKeys + hiddenKeys
        save()
    }

    func visiblePreferredKeys(from availableKeys: [HomeFeatureKey]) -> [HomeFeatureKey]
    {
        let allowed = Set(availableKeys)
        return preferredKeys.filter { allowed.contains($0) }
    }

    private func save()
    {
        if let data = try? JSONEncoder().encode(preferredKeys)
        {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

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

        if !context.coordinator.isInteractivelyMoving
        {
            collectionView.reloadData()
        }
    }

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
