import SwiftUI

struct ElectricityView: View
{
    @EnvironmentObject var userinfo: userInfo
    @AppStorage("hzau_room_id") var savedRoomId: String = ""
    @AppStorage("hzau_room_name") var savedRoomName: String = ""

    @State private var electricityRecords: [ElectricityRecord] = []
    @State private var isLoading = false

    // 绑定弹窗与联动状态
    @State private var showBindingSheet = false
    @State private var buildings: [PickerItem] = []
    @State private var floors: [PickerItem] = []
    @State private var rooms: [PickerItem] = []

    @State private var selectedBuildingId = ""
    @State private var selectedFloorId = ""
    @State private var selectedRoomId = ""

    // 弹窗提示
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showMFASheet = false
    @State private var mfaMaskedPhone = ""
    @State private var mfaCode = ""
    @State private var mfaContinuation: CheckedContinuation<String?, Never>?
    @State private var sessionToken: String = ""
    @State private var loginTask: Task<String, Error>?

    private let query = ElectricityQuery()

    var body: some View
    {
        ZStack
        {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            VStack
            {
                if savedRoomId.isEmpty
                {
                    emptyStateView
                }
                else
                {
                    contentView
                }
            }

            VStack
            {
                Spacer()
                ElectricityBindingButton(prepareBinding: prepareBinding, savedRoomId: $savedRoomId)
            }

            if isLoading
            {
                ProgressView("正在同步...")
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)))
                    .shadow(radius: 10)
                    .padding(.bottom, 50)
            }
        }
        .navigationTitle("电费查询")
        .toolbar(.hidden, for: .tabBar)

        .onAppear
        {
            if !savedRoomId.isEmpty
            {
                fetchElectricity()
            }
        }
        .sheet(isPresented: $showBindingSheet)
        {
            bindingWheelView
        }
        .alert(isPresented: $showAlert)
        {
            Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("好")))
        }
        .sheet(isPresented: $showMFASheet) {
            MFACodeInputSheet(
                maskedPhone: mfaMaskedPhone,
                code: $mfaCode,
                onCancel: { resolveMFACode(nil) },
                onConfirm: { resolveMFACode(mfaCode.trimmingCharacters(in: .whitespacesAndNewlines)) }
            )
        }
    }

    // MARK: - 主内容视图

    private var contentView: some View
    {
        ScrollView
        {
            VStack(spacing: 16)
            {
                if let record = electricityRecords.first
                {
                    // 余额大卡片
                    VStack(alignment: .leading, spacing: 12)
                    {
                        HStack
                        {
                            VStack(alignment: .leading, spacing: 4)
                            {
                                Text("当前余额 (元)")
                                    .font(.subheadline)
                                    .opacity(0.8)
                                Text(record.balance)
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                            }
                            Spacer()
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.yellow)
                        }

                        Divider().background(Color.white.opacity(0.3))

                        HStack
                        {
                            Label(record.accountAddress, systemImage: "mappin.and.ellipse")
                            Spacer()
                            Text(record.roomTypeName ?? "本科生")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.white.opacity(0.2)))
                        }
                    }
                    .padding(24)
                    .background(
                        .blue
                    )
                    .foregroundColor(.white)
                    .cornerRadius(25)
                    .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)

                    VStack(alignment: .leading, spacing: 12)
                    {
                        HStack
                        {
                            VStack(alignment: .leading, spacing: 4)
                            {
                                Text("电表读数 (度)")
                                    .font(.subheadline)
                                    .opacity(0.8)
                                Text("\(record.baseMeterList?.first?.lastReading ?? 0, specifier: "%.2f")")
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                            }
                            Spacer()
                            Image(systemName: "gauge.medium")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(24)
                    .background(
                        .green
                    )
                    .foregroundColor(.white)
                    .cornerRadius(25)
                    .shadow(color: Color.green.opacity(0.3), radius: 10, x: 0, y: 5)

                    // 详情列表
                    VStack(spacing: 0)
                    {
                        infoRow(title: "最后抄表时间", value: record.lastUpdate, icon: "clock", color: .green)
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(15)
                }
            }
            .padding()
        }
        .refreshable
        {
            fetchElectricity()
        }
    }

    // MARK: - 未绑定视图

    private var emptyStateView: some View
    {
        VStack(spacing: 20)
        {
            Spacer()
            Image(systemName: "bolt.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue.opacity(0.6))

            VStack(spacing: 8)
            {
                Text("尚未绑定房间")
                    .font(.title2.bold())
                Text("绑定后可随时查看宿舍剩余电费")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
    }

    // MARK: - 滚轮绑定视图 (Wheel Picker)

    private var bindingWheelView: some View
    {
        NavigationView
        {
            VStack(spacing: 0)
            {
                Text("请选择宿舍房间号")
                    .font(.subheadline).foregroundColor(.secondary).padding(.top)

                HStack(spacing: 0)
                {
                    // 楼栋 Picker
                    Picker("楼栋", selection: $selectedBuildingId)
                    {
                        ForEach(buildings) { Text($0.label).tag($0.value) }
                    }
                    .pickerStyle(.wheel)
                    .onChange(of: selectedBuildingId)
                    { newValue in
                        updateFloors(for: newValue)
                    }

                    // 楼层 Picker
                    Picker("楼层", selection: $selectedFloorId)
                    {
                        if floors.isEmpty { Text("-").tag("") }
                        ForEach(floors) { Text($0.label).tag($0.value) }
                    }
                    .pickerStyle(.wheel)
                    .onChange(of: selectedFloorId)
                    { newValue in
                        let floorNum = newValue.components(separatedBy: "-").first ?? newValue
                        updateRooms(buildingId: selectedBuildingId, floor: floorNum)
                    }
                    // 房间 Picker
                    Picker("房间", selection: $selectedRoomId)
                    {
                        if rooms.isEmpty { Text("-").tag("") }
                        ForEach(rooms) { Text($0.label).tag($0.value) }
                    }
                    .pickerStyle(.wheel)
                }
                .frame(height: 250)

                // 路径预览
                VStack(alignment: .leading, spacing: 12)
                {
                    Text("当前选择").font(.caption).foregroundColor(.secondary)
                    HStack
                    {
                        Image(systemName: "location.fill").foregroundColor(.blue)
                        Text(getCurrentSelectionPath())
                            .font(.headline)
                        Spacer()
                    }
                    .padding().background(Color(.secondarySystemGroupedBackground)).cornerRadius(12)
                }
                .padding()
                Spacer()
            }
            .navigationTitle("绑定房间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar
            {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { showBindingSheet = false } }
                ToolbarItem(placement: .confirmationAction)
                {
                    Button("完成") { confirmBinding() }
                        .disabled(selectedRoomId.isEmpty)
                }
            }
        }
    }

    private func getCurrentSelectionPath() -> String
    {
        let b = buildings.first(where: { $0.value == selectedBuildingId })?.label ?? ""
        let f = floors.first(where: { $0.value == selectedFloorId })?.label ?? ""
        let r = rooms.first(where: { $0.value == selectedRoomId })?.label ?? ""
        return "\(b) \(f) \(r)".trimmingCharacters(in: .whitespaces)
    }

    private func infoRow(title: String, value: String, icon: String, color: Color) -> some View
    {
        HStack(spacing: 15)
        {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            VStack(alignment: .leading)
            {
                Text(title).font(.caption).foregroundColor(.secondary)
                Text(value).font(.body)
            }
            Spacer()
        }
        .padding()
    }

    // MARK: - 业务逻辑

    private func prepareBinding()
    {
        isLoading = true
        Task
        {
            do
            {
                let token = try await loginToken()
                let list = try await query.fetchBuildingList(token: token)
                await MainActor.run
                {
                    self.buildings = list
                    if let first = list.first
                    {
                        self.selectedBuildingId = first.value
                        // 初始加载第一栋楼的楼层
                        fetchFloors(buildingId: first.value)
                    }
                    self.isLoading = false
                    self.showBindingSheet = true
                }
            }
            catch { await showError(error) }
        }
    }

    private func updateFloors(for bId: String)
    {
        Task
        {
            let token = try await loginToken()
            let list = try await query.fetchFloorList(token: token, buildingId: bId)
            await MainActor.run
            {
                self.floors = list
                if let firstFloor = list.first
                {
                    self.selectedFloorId = firstFloor.value
                    // 注意这里：从 "1-1770..." 中提取出 "1"
                    let floorNum = firstFloor.value.components(separatedBy: "-").first ?? firstFloor.value
                    updateRooms(buildingId: bId, floor: floorNum)
                }
            }
        }
    }

    private func updateRooms(buildingId: String, floor: String)
    {
        Task
        {
            let token = try await loginToken()
            let list = try await query.fetchRoomList(token: token, buildingId: buildingId, floorNum: floor)
            await MainActor.run
            {
                self.rooms = list
                self.selectedRoomId = list.first?.value ?? ""
            }
        }
    }

    private func fetchFloors(buildingId: String)
    {
        Task
        {
            do
            {
                let token = try await loginToken()
                let list = try await query.fetchFloorList(token: token, buildingId: buildingId)
                await MainActor.run
                {
                    self.floors = list
                    if let first = list.first
                    {
                        self.selectedFloorId = first.value
                        // 加载第一层的房间
                        let floorNum = first.value.components(separatedBy: "-").first ?? first.value
                        fetchRooms(buildingId: buildingId, floor: floorNum)
                    }
                }
            }
            catch { await showError(error) }
        }
    }

    private func fetchRooms(buildingId: String, floor: String)
    {
        Task
        {
            do
            {
                let token = try await loginToken()
                // 这里调用的是 API: /base/rooms/getRoomListByBuildIdAndFloor
                let list = try await query.fetchRoomList(token: token, buildingId: buildingId, floorNum: floor)
                await MainActor.run
                {
                    self.rooms = list
                    if let first = list.first
                    {
                        self.selectedRoomId = first.value
                    }
                    else
                    {
                        self.selectedRoomId = ""
                    }
                }
            }
            catch { await showError(error) }
        }
    }

    private func confirmBinding()
    {
        if let room = rooms.first(where: { $0.value == selectedRoomId })
        {
            savedRoomId = selectedRoomId
            savedRoomName = room.label
            showBindingSheet = false
            fetchElectricity()
        }
    }

    private func fetchElectricity()
    {
        isLoading = true
        Task
        {
            do
            {
                let token = try await loginToken()
                let records = try await query.fetchElectricityAccount(token: token, roomId: savedRoomId)
                await MainActor.run
                {
                    self.electricityRecords = records
                    self.isLoading = false
                    ElectricityBGTaskManager.shared.scheduleNext()
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            catch { await showError(error) }
        }
    }

    private func showError(_ error: Error) async
    {
        await MainActor.run
        {
            isLoading = false
            alertTitle = "错误"
            if let nsError = error as NSError?, nsError.code == 401 || nsError.code == 403
            {
                sessionToken = ""
                loginTask = nil
            }
            if(userinfo.username.isEmpty && userinfo.plainPassword.isEmpty)
            {
                self.alertMessage = "好像忘记了登录，请先去登录吧！"
            }
            else
            {
                if let nsError = error as NSError?,
                   let serverMessage = nsError.userInfo["msg"] as? String,
                   !serverMessage.isEmpty
                {
                    alertMessage = "\(serverMessage)（code: \(nsError.code)）"
                }
                else
                {
                    alertMessage = error.localizedDescription
                }
            }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            showAlert = true
        }
    }

    private func loginToken() async throws -> String {
        if !sessionToken.isEmpty
        {
            return sessionToken
        }

        if let existingTask = loginTask
        {
            return try await existingTask.value
        }

        let task = Task<String, Error> {
            try await query.loginAndGetToken(
                username: userinfo.username,
                rsaPassword: userinfo.encryptedPasswordSchool,
                mfaCodeProvider: { phone in
                    await requestMFACode(maskedPhone: phone)
                }
            )
        }

        await MainActor.run
        {
            loginTask = task
        }

        do
        {
            let token = try await task.value
            await MainActor.run
            {
                sessionToken = token
                loginTask = nil
            }
            return token
        }
        catch
        {
            await MainActor.run
            {
                loginTask = nil
            }
            throw error
        }
    }

    @MainActor
    private func requestMFACode(maskedPhone: String?) async -> String? {
        mfaMaskedPhone = maskedPhone ?? ""
        mfaCode = ""
        showMFASheet = true
        return await withCheckedContinuation { continuation in
            mfaContinuation = continuation
        }
    }

    @MainActor
    private func resolveMFACode(_ code: String?) {
        showMFASheet = false
        mfaContinuation?.resume(returning: code)
        mfaContinuation = nil
    }
}

struct ElectricityBindingButton: View
{
    var prepareBinding: () -> Void

    @Binding var savedRoomId: String

    var body: some View
    {
        HStack(spacing: 20)
        {
            // 2. 刷新/查询按钮（中间核心位置）
            Button(action: {
                prepareBinding()
            })
            {
                if !savedRoomId.isEmpty
                {
                    Text("重新绑定")
                        .font(.headline)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 25)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                else
                {
                    Text("绑定房间")
                        .font(.headline)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 25)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
            .optionalLiquidGlass()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .glassBackground(cornerRadius: 64)
        .padding(.horizontal, 20)
        .padding(.bottom, 30) // 距离底部安全区域的距离
    }
}

#Preview
{
    ElectricityView()
        .environmentObject(userInfo())
}
