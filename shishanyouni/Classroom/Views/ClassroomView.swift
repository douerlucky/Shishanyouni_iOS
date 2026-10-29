import SwiftUI

struct ClassroomView: View
{
    @EnvironmentObject var userinfo: userInfo

    @State private var rooms: [RoomStatus] = []
    @State private var isLoading = false

    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var errorRetryAction: (() -> Void)?

    // 默认查询参数：今天、三教、A栋、1楼
    @State private var selectedDate = Date()
    @State private var selectedBuilding = "三教"
    @State private var selectedWing = "A"
    @State private var selectedFloor = 1

    let classroomService = ClassroomAPI()

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
                            .tint(appActionBlue)
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
                errorRetryAction: $errorRetryAction,
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
            Button("重试") { errorRetryAction?() }
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
