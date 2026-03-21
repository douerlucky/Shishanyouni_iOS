//
//  ClassroomView.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/3/21.
//

import SwiftUI

struct ClassroomView: View
{
    @EnvironmentObject var userinfo: userInfo

    @State private var rooms: [RoomStatus] = []
    @State private var isLoading = false

    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""

    // 默认查询参数：今天、三教、A栋、1楼
    @State private var selectedDate = Date()
    @State private var selectedBuilding = "三教"
    @State private var selectedWing = "A"
    @State private var selectedFloor = 1

    let classroomService = ClassroomService()

    /// 关注教室全局 Store
    @StateObject private var favoritesStore = FavoriteClassroomStore()

    /// 当前查询楼层的 API siteName，如 "三教A1"
    var siteName: String
    {
        let wingStr = selectedWing == "无" ? "" : selectedWing
        return "\(selectedBuilding)\(wingStr)\(selectedFloor)"
    }

    /// 与底部栏一致的日期字符串
    var dateString: String
    {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: selectedDate)
    }

    var body: some View
    {
        ZStack(alignment: .bottom)
        {
            ZStack
            {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                ClassroomMatrixView(
                    rooms: rooms,
                    building: selectedBuilding,
                    wing: selectedWing,
                    floor: selectedFloor,
                    favoritesStore: favoritesStore,
                    currentSiteName: siteName
                )
                .blur(radius: isLoading ? 3 : 0)

                if isLoading
                {
                    VStack(spacing: 15)
                    {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.blue)
                        Text("正在查询...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 180, height: 120)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .shadow(radius: 10)
                }
            }

            BottomClassroomButtonView(
                isLoading: $isLoading,
                rooms: $rooms,
                showAlert: $showAlert,
                alertTitle: $alertTitle,
                alertMessage: $alertMessage,
                selectedDate: $selectedDate,
                selectedBuilding: $selectedBuilding,
                selectedWing: $selectedWing,
                selectedFloor: $selectedFloor,
                classroomService: classroomService
            )
        }
        .navigationTitle("空教室查询")
        .toolbar(.hidden, for: .tabBar)
        .navigationBarTitleDisplayMode(.large)
        .alert(alertTitle, isPresented: $showAlert)
        {
            Button("好哒", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        // 日期变化 或 关注列表增减 时，同步刷新关注教室数据
        // 用 dateString + favorites.count 组合作为 task id，任意一个变化都会重新触发
        .task(id: dateString + "_\(favoritesStore.favorites.count)")
        {
            await favoritesStore.fetchSlots(dateStr: dateString, service: classroomService)
        }
    }
}

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



                ForEach(favoritesStore.favorites)
                { fav in
                    FavoriteRoomRowView(fav: fav, favoritesStore: favoritesStore, cellHeight: cellHeight)

                }
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
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
            Text(fav.displayName)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.orange)
                .frame(width: 52)
                .frame(height: cellHeight)
                .padding(.leading, 4)

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
            Text(name)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(isFav ? .orange : .secondary)
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
        }
        .padding(.trailing, 4)
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
                                ) {
                                    if isFav {
                                        favoritesStore.remove(siteName: currentSiteName, arrayIndex: room.arrayIndex)
                                    } else {
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
                    .padding(.bottom, 140)
                }
            }
        }
    }
}

// MARK: - 底部浮动按钮栏

struct BottomClassroomButtonView: View
{
    @Binding var isLoading: Bool
    @Binding var rooms: [RoomStatus]
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String

    @Binding var selectedDate: Date
    @Binding var selectedBuilding: String
    @Binding var selectedWing: String
    @Binding var selectedFloor: Int

    @State private var showPicker = false
    let classroomService: ClassroomService

    let buildings = ["一教", "二教", "三教", "四教"]

    var availableWings: [String]
    {
        if selectedBuilding == "一教" || selectedBuilding == "二教" { return ["无"] }
        return ["A", "B", "C"]
    }

    var maxFloor: Int
    {
        if selectedBuilding == "一教" || selectedBuilding == "三教" { return 5 }
        if selectedBuilding == "二教" { return 4 }
        if selectedBuilding == "四教" { return selectedWing == "A" ? 4 : 5 }
        return 5
    }

    var siteName: String
    {
        let wingStr = selectedWing == "无" ? "" : selectedWing
        return "\(selectedBuilding)\(wingStr)\(selectedFloor)"
    }

    var displayLocation: String
    {
        let wingStr = selectedWing == "无" ? "" : "\(selectedWing)栋"
        return "\(selectedBuilding)\(wingStr)\(selectedFloor)楼"
    }

    var dateString: String
    {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: selectedDate)
    }

    var body: some View
    {
        HStack(spacing: 8)
        {
            HStack(spacing: 0)
            {
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .labelsHidden()
            }
            .background(Color(.systemBackground).opacity(0.9))
            .clipShape(Capsule())
            .optionalLiquidGlass()

            Spacer(minLength: 4)

            Button(action: { showPicker = true })
            {
                HStack(spacing: 4)
                {
                    Text(displayLocation)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .background(Color(.systemBackground).opacity(0.9))
            .clipShape(Capsule())
            .optionalLiquidGlass()

            Button(action: performSearch)
            {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.blue)
                    .clipShape(Circle())
            }
            .optionalLiquidGlass()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .glassBackground(cornerRadius: 64)
        .padding(.horizontal, 16)
        .padding(.bottom, 25)
        .sheet(isPresented: $showPicker)
        {
            PickerSheetView(
                selectedBuilding: $selectedBuilding,
                selectedWing: $selectedWing,
                selectedFloor: $selectedFloor,
                buildings: buildings,
                availableWings: availableWings,
                maxFloor: maxFloor
            )
        }
        .onChange(of: selectedDate) { _ in performSearch() }
        .onChange(of: showPicker) { isPresented in if !isPresented { performSearch() } }
        .onAppear { performSearch() }
    }

    private func performSearch()
    {
        isLoading = true
        Task
        {
            defer { isLoading = false }
            do
            {
                rooms = try await classroomService.fetchEmptyRooms(dateStr: dateString, siteName: siteName)
                await MainActor.run
                {
                    if rooms.isEmpty
                    {
                        alertTitle = "噫！"
                        alertMessage = "没有找到数据，系统好像有问题！"
                    }
                    else
                    {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                }
            }
            catch
            {
                await MainActor.run
                {
                    alertTitle = "哎呀，出错了"
                    alertMessage = error.localizedDescription
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    showAlert = true
                }
            }
        }
    }
}

// MARK: - 教室位置选择器

struct PickerSheetView: View
{
    @Environment(\.dismiss) var dismiss

    @Binding var selectedBuilding: String
    @Binding var selectedWing: String
    @Binding var selectedFloor: Int

    let buildings: [String]
    let availableWings: [String]
    let maxFloor: Int

    var body: some View
    {
        NavigationView
        {
            VStack(spacing: 20)
            {
                Text("教室位置")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                HStack(spacing: 0)
                {
                    Picker("教学楼", selection: $selectedBuilding)
                    {
                        ForEach(buildings, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .onChange(of: selectedBuilding)
                    { newValue in
                        if newValue == "一教" || newValue == "二教" { selectedWing = "无" }
                        else if selectedWing == "无" { selectedWing = "A" }
                        validateFloor()
                    }

                    Picker("栋号", selection: $selectedWing)
                    {
                        ForEach(availableWings, id: \.self)
                        { wing in
                            Text(wing == "无" ? "不分栋" : "\(wing)栋").tag(wing)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .onChange(of: selectedWing) { _ in validateFloor() }
                    .opacity((selectedBuilding == "一教" || selectedBuilding == "二教") ? 0.3 : 1.0)
                    .disabled(selectedBuilding == "一教" || selectedBuilding == "二教")

                    Picker("楼层", selection: $selectedFloor)
                    {
                        ForEach(1 ... maxFloor, id: \.self) { Text("\($0) 楼").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()
                }
                .padding(.horizontal, 10)

                Spacer()
            }
            .navigationTitle("教学楼过滤")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar
            {
                ToolbarItem(placement: .confirmationAction)
                {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(300), .medium])
    }

    private func validateFloor()
    {
        if selectedFloor > maxFloor { selectedFloor = maxFloor }
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
