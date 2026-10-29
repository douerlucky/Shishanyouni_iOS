import SwiftUI

// 关注教室区域

struct FavoritesSectionView: View
{
    @ObservedObject var favoritesStore: FavoriteClassroomStore
    let slotTitles: [String]
    let cellHeight: CGFloat

    var body: some View
    {
        VStack(spacing: 0)
        {
            // 标题栏
            HStack(spacing: 6)
            {
                Image(systemName: "star.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.orange)
                Text("关注的教室")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                if favoritesStore.isFetchingFavorites
                {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if favoritesStore.favorites.isEmpty
            {
                // 空状态提示
                HStack(spacing: 12)
                {
                    Image(systemName: "hand.tap")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary.opacity(0.4))
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 3)
                    {
                        Text("还没有关注的教室")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("长按下方查询结果中的教室名称，可以添加关注，在此处优先显示今日占用情况")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.6))
                            .lineLimit(3)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
            else
            {
                // 节次表头
                HStack(spacing: 0)
                {
                    Text("教室")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 52)
                        .padding(.vertical, 7)

                    ForEach(slotTitles, id: \.self)
                    { title in
                        Text(title)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 7)
                    }
                }
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity)

                ForEach(favoritesStore.favorites)
                { fav in
                    FavoriteRoomRowView(fav: fav, favoritesStore: favoritesStore, cellHeight: cellHeight)
                }
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .frame(maxWidth: .infinity)
    }
}

// 关注教室单行

struct FavoriteRoomRowView: View
{
    let fav: FavoriteClassroom
    @ObservedObject var favoritesStore: FavoriteClassroomStore
    let cellHeight: CGFloat

    var body: some View
    {
        let key = favoritesStore.slotKey(fav)
        let slots = favoritesStore.slotsMap[key]

        HStack(spacing: 0)
        {
            if fav.displayName.count >= 8
            {
                Text(fav.displayName)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .frame(width: 52)
                    .frame(height: cellHeight)
                    .padding(.leading, 4)
            }
            else
            {
                Text(fav.displayName)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .frame(width: 52)
                    .frame(height: cellHeight)
                    .padding(.leading, 4)
            }

            HStack(spacing: 0)
            {
                ForEach(0 ..< 5, id: \.self)
                { col in
                    slotCell(slots: slots, col: col)
                }
            }
            .padding(.leading, 6)
        }
        .padding(.trailing, 4)
        .frame(maxWidth: .infinity)
        .contextMenu
        {
            Button(role: .destructive)
            {
                favoritesStore.remove(siteName: fav.siteName, arrayIndex: fav.arrayIndex)
            } label: {
                Label("取消关注", systemImage: "star.slash")
            }
        }
    }

    @ViewBuilder
    private func slotCell(slots: [Int]?, col: Int) -> some View
    {
        let isReady = slots != nil
        let isOccupied = slots?[col] == 1

        ZStack
        {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    !isReady
                        ? Color.secondary.opacity(0.07)
                        : isOccupied
                        ? Color.red.opacity(0.1)
                        : Color.green.opacity(0.15)
                )

            if !isReady
            {
                Text("—")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.35))
            }
            else
            {
                Text(isOccupied ? "上课" : "空闲")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isOccupied ? .red : .green)
            }
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 4)
        .frame(height: cellHeight)
        .frame(maxWidth: .infinity)
    }
}

// 单行

struct ClassroomRowView: View
{
    let room: RoomStatus
    let name: String
    let isFav: Bool
    let cellHeight: CGFloat
    let onToggleFav: () -> Void

    var body: some View
    {
        HStack(spacing: 0)
        {
            // 左侧教室名
            if name.count >= 8
            {
                Text(name)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(isFav ? .orange : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .frame(width: 52)
                    .frame(height: cellHeight)
                    .padding(.leading, 4)
                    .overlay(alignment: .topTrailing)
                    {
                        if isFav
                        {
                            Image(systemName: "star.fill")
                                .font(.system(size: 7))
                                .foregroundColor(.orange)
                                .offset(x: -2, y: 4)
                        }
                    }
            }
            else
            {
                Text(name)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(isFav ? .orange : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .frame(width: 52)
                    .frame(height: cellHeight)
                    .padding(.leading, 4)
                    .overlay(alignment: .topTrailing)
                    {
                        if isFav
                        {
                            Image(systemName: "star.fill")
                                .font(.system(size: 7))
                                .foregroundColor(.orange)
                                .offset(x: -2, y: 4)
                        }
                    }
            }

            // 右侧占用矩阵
            HStack(spacing: 0)
            {
                ForEach(0 ..< 5, id: \.self)
                { colIndex in
                    let isOccupied = room.slots[colIndex] == 1

                    ZStack
                    {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isOccupied ? Color.red.opacity(0.1) : Color.green.opacity(0.15))

                        Text(isOccupied ? "上课" : "空闲")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isOccupied ? .red : .green)
                    }
                    .padding(.horizontal, 3)
                    .padding(.vertical, 4)
                    .frame(height: cellHeight)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.leading, 6)
            .frame(maxWidth: .infinity)
        }
        .padding(.trailing, 4)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .contextMenu
        {
            if isFav
            {
                Button(role: .destructive)
                {
                    onToggleFav()
                } label: {
                    Label("取消关注", systemImage: "star.slash")
                }
            }
            else
            {
                Button
                {
                    onToggleFav()
                } label: {
                    Label("关注此教室", systemImage: "star")
                }
            }
        }
    }
}

// MARK: - 空闲与否矩阵

struct ClassroomMatrixView: View
{
    let rooms: [RoomStatus]
    let building: String
    let wing: String
    let floor: Int

    @ObservedObject var favoritesStore: FavoriteClassroomStore
    let currentSiteName: String

    let slotTitles = ["1-2节", "3-4节", "5-6节", "7-8节", "9-12节"]
    let cellHeight: CGFloat = 44

    private func roomName(arrayIndex: Int) -> String
    {
        let wingStr = wing == "无" ? "" : wing
        return "\(building)\(wingStr)\(floor)\(String(format: "%02d", arrayIndex + 1))"
    }

    var body: some View
    {
        VStack(spacing: 0)
        {
            ScrollView
            {
                // 关注教室区域（始终在顶部）
                FavoritesSectionView(
                    favoritesStore: favoritesStore,
                    slotTitles: slotTitles,
                    cellHeight: cellHeight
                )

                .padding(.horizontal, 10)
                .padding(.top, 10)

                // 主查询结果
                if rooms.isEmpty
                {
                    VStack(spacing: 12)
                    {
                        Image(systemName: "square.grid.3x3.topleft.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("暂无教室数据或未开始查询")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                }
                else
                {
                    VStack(spacing: 0)
                    {
                        // 节次表头
                        HStack(spacing: 0)
                        {
                            Text("教室")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.secondary)
                                .frame(width: 52)
                                .padding(.vertical, 10)

                            ForEach(slotTitles, id: \.self)
                            { title in
                                Text(title)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.horizontal, 4)
                        .frame(maxWidth: .infinity)

                        // 按行渲染
                        VStack(spacing: 0)
                        {
                            ForEach(rooms)
                            { room in
                                let name = roomName(arrayIndex: room.arrayIndex)
                                let isFav = favoritesStore.isFavorited(
                                    siteName: currentSiteName,
                                    arrayIndex: room.arrayIndex
                                )

                                ClassroomRowView(
                                    room: room,
                                    name: name,
                                    isFav: isFav,
                                    cellHeight: cellHeight
                                )
                                {
                                    if isFav
                                    {
                                        favoritesStore.remove(siteName: currentSiteName, arrayIndex: room.arrayIndex)
                                    }
                                    else
                                    {
                                        favoritesStore.add(siteName: currentSiteName, arrayIndex: room.arrayIndex, displayName: name)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .padding(10)
                    .frame(maxWidth: .infinity)
                }
            }
            .safeAreaInset(edge: .bottom)
            {
                Color.clear.frame(height: 100)
            }
        }
    }
}

#Preview
{
    NavigationView
    {
        ClassroomView()
            .environmentObject(userInfo())
    }
}
