import SwiftUI

// MARK: - 底部浮动按钮栏

struct BottomClassroomButtonView: View
{
    @Binding var isLoading: Bool
    @Binding var rooms: [RoomStatus]
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    @Binding var errorRetryAction: (() -> Void)?

    @Binding var selectedDate: Date
    @Binding var selectedBuilding: String
    @Binding var selectedWing: String
    @Binding var selectedFloor: Int

    @State private var showPicker = false
    let classroomService: ClassroomAPI

    let buildings = ["一教", "二教", "三教", "四教", "襄阳校区二教"]
    var availableWings: [String]
    {
        if selectedBuilding == "一教" || selectedBuilding == "二教" || selectedBuilding == "襄阳校区二教" { return ["无"] }
        return ["A", "B", "C"]
    }

    var maxFloor: Int
    {
        if selectedBuilding == "一教" || selectedBuilding == "三教" { return 5 }
        if selectedBuilding == "二教" { return 4 }
        if selectedBuilding == "四教" { return selectedWing == "A" ? 4 : 5 }
        if selectedBuilding == "襄阳校区二教" { return 2 }
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

    private var semesterStartDate: Date
    {
        CurriculumStore.shared.loadSemesterStartDate() ?? Date()
    }

    private var selectedWeek: Int
    {
        var cal = Calendar.current
        cal.firstWeekday = 2

        let startComponents = cal.dateComponents(
            [.yearForWeekOfYear, .weekOfYear],
            from: semesterStartDate
        )
        let selectedComponents = cal.dateComponents(
            [.yearForWeekOfYear, .weekOfYear],
            from: selectedDate
        )
        guard let startMonday = cal.date(from: startComponents),
              let selectedMonday = cal.date(from: selectedComponents)
        else { return 1 }

        let difference = cal.dateComponents(
            [.weekOfYear],
            from: startMonday,
            to: selectedMonday
        ).weekOfYear ?? 0
        return max(difference + 1, 1)
    }

    private var selectedWeekday: String
    {
        let weekday = Calendar.current.component(.weekday, from: selectedDate)
        let names = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        return names[weekday - 1]
    }

    var body: some View
    {
        VStack(spacing: 8)
        {
            HStack(spacing: 4)
            {
                NextButton(systemImage: "chevron.left.2", size: 26)
                {
                    shiftDate(by: -7)
                }

                NextButton(systemImage: "chevron.left", size: 26)
                {
                    shiftDate(by: -1)
                }

                VStack(spacing: 1)
                {
                    Text("第 \(selectedWeek) 周")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(appActionBlue)
                    Text(selectedWeekday)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 70)

                NextButton(systemImage: "chevron.right", size: 26)
                {
                    shiftDate(by: 1)
                }

                NextButton(systemImage: "chevron.right.2", size: 26)
                {
                    shiftDate(by: 7)
                }

                Spacer(minLength: 8)

                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .labelsHidden()
                    .tint(appActionBlue)
                    .frame(width: 96)
                    .scaleEffect(0.8)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 8)
            {
                TeachingBuildingSelector(title: displayLocation) { showPicker = true }
                    .frame(maxWidth: .infinity)

                SearchButton("搜索", action: performSearch)
            }
            .frame(maxWidth: .infinity)
        }
        .queryBottomIndicatorBar(cornerRadius: 24)
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
                    errorRetryAction = { [self] in performSearch() }
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    showAlert = true
                }
            }
        }
    }

    private func shiftDate(by days: Int)
    {
        guard let date = Calendar.current.date(byAdding: .day, value: days, to: selectedDate)
        else { return }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        selectedDate = Calendar.current.startOfDay(for: date)
    }
}
