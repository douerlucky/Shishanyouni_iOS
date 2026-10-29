import SwiftUI
import UIKit

/// 常用功能和全部功能共用三列布局、图标样式与系统拖放，不再维护两套排序手势。
struct HomeFeatureGridView: UIViewRepresentable
{
    enum Kind: Equatable
    {
        case favorites
        case catalog(favorites: Set<HomeFeatureKey>)

        var accessoryIcon: String
        {
            if case .favorites = self { return "minus" }
            return "plus"
        }

        var accessoryColor: Color
        {
            if case .favorites = self { return .red }
            return .green
        }

        func showsAccessory(for key: HomeFeatureKey) -> Bool
        {
            if case let .catalog(favorites) = self { return !favorites.contains(key) }
            return true
        }
    }

    private static let itemHeight: CGFloat = 126
    private static let lineSpacing: CGFloat = 16
    private static let verticalInset: CGFloat = 10

    let features: [HomeFeatureItem]
    let isEditing: Bool
    var kind: Kind = .favorites
    let onSelect: (HomeFeatureItem) -> Void
    let onAccessory: (HomeFeatureItem) -> Void
    let onStartEditing: () -> Void
    let onReorder: ([HomeFeatureKey]) -> Void

    static func height(for count: Int) -> CGFloat
    {
        guard count > 0 else { return 0 }
        let rows = (count + 2) / 3
        return CGFloat(rows) * itemHeight + CGFloat(rows - 1) * lineSpacing + verticalInset * 2
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UICollectionView
    {
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0 / 3), heightDimension: .absolute(Self.itemHeight)
        ))
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(Self.itemHeight)),
            repeatingSubitem: item,
            count: 3
        )
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = Self.lineSpacing
        section.contentInsets = NSDirectionalEdgeInsets(top: Self.verticalInset, leading: 0, bottom: Self.verticalInset, trailing: 0)

        let collection = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewCompositionalLayout(section: section))
        collection.backgroundColor = .clear
        collection.clipsToBounds = false
        collection.contentInsetAdjustmentBehavior = .never
        collection.isScrollEnabled = false
        collection.allowsSelection = false
        collection.dragInteractionEnabled = true
        collection.reorderingCadence = .immediate
        collection.dataSource = context.coordinator
        collection.dragDelegate = context.coordinator
        collection.dropDelegate = context.coordinator
        collection.register(UICollectionViewCell.self, forCellWithReuseIdentifier: Coordinator.cellIdentifier)
        return collection
    }

    func updateUIView(_ collection: UICollectionView, context: Context)
    {
        let coordinator = context.coordinator
        coordinator.parent = self
        // 拖放期间的数据快照属于 UIKit；首页时钟刷新不能覆盖它或重建单元格。
        if coordinator.isDragging
        {
            // 长按进入编辑后立即显示加减号，但不替换拖放中的数据或 reloadData。
            if isEditing != coordinator.renderedIsEditing || kind != coordinator.renderedKind
            {
                coordinator.refreshVisibleCells(in: collection)
            }
            return
        }
        let keys = features.map(\.key)
        if keys != coordinator.renderedKeys
        {
            coordinator.currentFeatures = features
            coordinator.renderedKeys = keys
            coordinator.renderedIsEditing = isEditing
            coordinator.renderedKind = kind
            collection.reloadData()
        }
        else if isEditing != coordinator.renderedIsEditing || kind != coordinator.renderedKind
        {
            coordinator.refreshVisibleCells(in: collection)
        }
    }

    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDragDelegate, UICollectionViewDropDelegate
    {
        static let cellIdentifier = "HomeFeatureCell"
        var parent: HomeFeatureGridView
        var currentFeatures: [HomeFeatureItem]
        var renderedKeys: [HomeFeatureKey]
        var renderedIsEditing: Bool
        var renderedKind: Kind
        var isDragging = false

        init(parent: HomeFeatureGridView)
        {
            self.parent = parent
            currentFeatures = parent.features
            renderedKeys = parent.features.map(\.key)
            renderedIsEditing = parent.isEditing
            renderedKind = parent.kind
            super.init()
        }

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
        {
            currentFeatures.count
        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
        {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Self.cellIdentifier, for: indexPath)
            configure(cell, at: indexPath)
            return cell
        }

        private func configure(_ cell: UICollectionViewCell, at indexPath: IndexPath)
        {
            guard currentFeatures.indices.contains(indexPath.item) else { return }
            let feature = currentFeatures[indexPath.item]
            let kind = parent.kind
            let isEditing = parent.isEditing
            cell.backgroundColor = .clear
            cell.contentView.backgroundColor = .clear
            cell.clipsToBounds = false
            cell.contentView.clipsToBounds = false
            cell.accessibilityIdentifier = "home-feature-\(feature.key.rawValue)"
            cell.contentConfiguration = UIHostingConfiguration
            {
                MenuGridItem(title: feature.title, icon: feature.icon, color: feature.color, isEditing: isEditing, onLongPress: { [weak self] in
                    guard let self, !self.parent.isEditing else { return }
                    self.parent.onStartEditing()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }) { [weak self] in
                    guard let self, !self.parent.isEditing,
                          let current = self.parent.features.first(where: { $0.key == feature.key })
                    else { return }
                    self.parent.onSelect(current)
                }
                .overlay(alignment: .top)
                {
                    if isEditing, kind.showsAccessory(for: feature.key)
                    {
                        NextButton(systemImage: kind.accessoryIcon, tint: kind.accessoryColor, size: 28)
                        { [weak self] in
                            guard let self, !self.isDragging else { return }
                            self.parent.onAccessory(feature)
                        }
                        .accessibilityLabel(kind.accessoryIcon == "minus" ? "移除\(feature.title)" : "添加\(feature.title)到常用功能")
                        .offset(x: MenuGridItem.iconSize / 2, y: -6)
                    }
                }
            }
            .margins(.all, 8)
        }

        func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem]
        {
            guard currentFeatures.indices.contains(indexPath.item) else { return [] }
            isDragging = true
            session.localContext = collectionView
            if !parent.isEditing
            {
                parent.onStartEditing()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            let key = currentFeatures[indexPath.item].key
            let item = UIDragItem(itemProvider: NSItemProvider(object: key.rawValue as NSString))
            item.localObject = key
            return [item]
        }

        func collectionView(_ collectionView: UICollectionView, dragSessionIsRestrictedToDraggingApplication session: UIDragSession) -> Bool { true }

        func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool
        {
            // 保留原有分类，不接受外部内容或把入口拖进另一个分类。
            (session.localDragSession?.localContext as? UICollectionView) === collectionView
        }

        func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal
        {
            UICollectionViewDropProposal(
                operation: self.collectionView(collectionView, canHandle: session) ? .move : .forbidden,
                intent: .insertAtDestinationIndexPath
            )
        }

        func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator)
        {
            guard self.collectionView(collectionView, canHandle: coordinator.session),
                  let item = coordinator.items.first, let source = item.sourceIndexPath,
                  currentFeatures.indices.contains(source.item)
            else { return }
            let destination = IndexPath(item: min(coordinator.destinationIndexPath?.item ?? currentFeatures.count - 1, currentFeatures.count - 1), section: 0)
            guard source != destination else
            {
                coordinator.drop(item.dragItem, toItemAt: destination)
                return
            }
            collectionView.performBatchUpdates
            {
                let moved = self.currentFeatures.remove(at: source.item)
                self.currentFeatures.insert(moved, at: destination.item)
                collectionView.moveItem(at: source, to: destination)
            }
            coordinator.drop(item.dragItem, toItemAt: destination)
            parent.onReorder(currentFeatures.map(\.key))
        }

        func collectionView(_ collectionView: UICollectionView, dragSessionDidEnd session: UIDragSession)
        {
            isDragging = false
            renderedKeys = currentFeatures.map(\.key)
            refreshVisibleCells(in: collectionView)
        }

        func refreshVisibleCells(in collectionView: UICollectionView)
        {
            renderedIsEditing = parent.isEditing
            renderedKind = parent.kind
            // 不 reloadData，以免打断系统落位动画；只同步已进入的真实编辑态。
            for indexPath in collectionView.indexPathsForVisibleItems
            {
                if let cell = collectionView.cellForItem(at: indexPath) { configure(cell, at: indexPath) }
            }
        }

        func collectionView(_ collectionView: UICollectionView, dragPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters?
        {
            let parameters = UIDragPreviewParameters()
            parameters.backgroundColor = .clear
            return parameters
        }
    }
}
