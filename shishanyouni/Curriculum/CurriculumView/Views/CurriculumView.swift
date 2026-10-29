import Combine
import SwiftUI
import UIKit

// MARK: - CurriculumView

struct CurriculumView: View
{
    @EnvironmentObject var userinfo: userInfo
    @EnvironmentObject private var iapStore: IAPStore
    @State private var showSettings = false
    @State var nowDisplayMonth: Int = -1
    @State private var courses: [Course] = []
    @State var datesCurWeek: [Int] = [-1, -1, -1, -1, -1, -1, -1]
    @State var weekDatesCurWeek: [Date] = Array(repeating: Date(), count: 7)
    @State var nowDisplayWeek: Int = -1

    @State private var inputWeek: String = ""
    @FocusState private var isWeekFieldFocused: Bool

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false

    @State private var showSaveSuccess = false
    @State private var backgroundImage: UIImage?

    @State private var addCourseContext: AddCourseContext?
    @State private var editCourseContext: Course?

    @AppStorage(PreferenceKey.enableLiquidGlassEffect) public var enableLiquidGlassEffect: Bool = false
    // 与 BackgroundSettingView 保持同一默认值；首次选择自定义背景时，课表默认可见。
    // 用户手动关闭后，AppStorage 中保存的 false 仍会优先于这个默认值。
    @AppStorage(PreferenceKey.curriculumBackgroundEnabled) private var curriculumBackgroundEnabled: Bool = true

    @State var semesterStartDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 2
        return Calendar.current.date(from: components) ?? Date()
    }()

    @AppStorage(PreferenceKey.semesterStartDateTimestamp) private var savedTimestamp: Double = 0
    @AppStorage(PreferenceKey.showBottomControls) private var showBottomControls: Bool = true
    // Key 名称不变，只是集中在 PreferenceKey 管理；已保存的设置会继续生效。
    @AppStorage(PreferenceKey.scheduleBackgroundImageFilename) private var backgroundImageFilename: String = ""
    @AppStorage(PreferenceKey.scheduleBackgroundOpacity) private var backgroundOpacity: Double = 0.2
    @AppStorage(PreferenceKey.curriculumFontScale) private var curriculumFontScale: Double = 1.0
    @AppStorage(PreferenceKey.showNoonPeriod) private var showNoonPeriod = false
    @AppStorage(PreferenceKey.showEveningPeriod) private var showEveningPeriod = false

    let calendar = Calendar.current
    let minWeek = -9
    let maxWeek = 30

    /// 关闭开关或校园通行证失效时只隐藏行，不会删除已经创建的课程。
    private var visiblePeriods: [Int]
    {
        CurriculumClassSchedule.displayOrder.filter
        { period in
            switch period
            {
            case CurriculumClassSchedule.noonPeriod:
                return showNoonPeriod && iapStore.hasActiveSubscription
            case CurriculumClassSchedule.eveningPeriod:
                return showEveningPeriod && iapStore.hasActiveSubscription
            default:
                return true
            }
        }
    }

    private var weekBinding: Binding<String>
    {
        Binding(
            get: { inputWeek.isEmpty ? "\(nowDisplayWeek)" : inputWeek },
            set: { newValue in
                inputWeek = newValue.filter { "0123456789".contains($0) }
            }
        )
    }

    private func saveCourses()
    {
        CurriculumStore.shared.saveCourses(courses, semesterStart: nil)
        CurriculumNotificationManager.shared.rescheduleAllNotifications()
    }

    /// 课表格按单个时间段渲染；长按其中一段时，编辑器需要拿到整门课。
    private func courseGroup(for course: Course) -> CourseGroup
    {
        let key = CourseGroupKey(course: course)
        let groupCourses = courses.filter { CourseGroupKey(course: $0) == key }
        return CourseGroup(id: key, courses: groupCourses)
    }

    /// 将冲突组内被用户点选的课程设为唯一优先项。
    /// 保存会触发 Widget 同步，因此 App、桌面、锁屏只会使用同一份选择结果。
    private func setDisplayPriority(for selectedCourse: Course, in conflictGroup: [Course])
    {
        let conflictIDs = Set(conflictGroup.map(\.id))
        guard conflictIDs.contains(selectedCourse.id) else { return }

        for index in courses.indices where conflictIDs.contains(courses[index].id)
        {
            courses[index].priority = courses[index].id == selectedCourse.id ? 1 : 0
        }

        saveCourses()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    var body: some View
    {
        VStack(spacing: 0)
        {
            // 顶部月份 + 星期头
            HStack(spacing: 0)
            {
                Text("\(nowDisplayMonth)月")
                    .font(.system(size: 13, weight: .medium))
                    .appTextOpacity()
                    .frame(width: 60)
                    .padding(.vertical, 8)

                WeekHeaderView(
                    weekDatesCurWeek: $weekDatesCurWeek,
                    datesCurWeek: $datesCurWeek
                )
            }
            .curriculumGlassPanel(in: Capsule(), enabled: enableLiquidGlassEffect)
            .clipShape(Capsule())
            .padding(.horizontal, 10)
            .padding(.top, 10)

            // 课表主体 + 底部控制条
            pageBodyView
        }
        .background
        {
            PageBackgroundView(
                image: backgroundImage,
                isEnabled: curriculumBackgroundEnabled,
                opacity: backgroundOpacity
            )
        }
        .onChange(of: backgroundImageFilename)
        { _ in
            loadBackgroundImage()
        }
        .onChange(of: savedTimestamp)
        { _ in
            loadSavedData()
            updateDatesForDisplayWeek()
        }
        .toolbar
        {
            ToolbarItem(placement: .navigationBarLeading)
            {
                Button(action: { showSettings = true })
                { Image(systemName: "gearshape").fontWeight(.medium) }
            }
            ToolbarItemGroup(placement: .navigationBarTrailing)
            {
                Button(action: {
                    exportCurriculumAsImage(
                        courses: courses,
                        week: nowDisplayWeek,
                        datesCurWeek: datesCurWeek,
                        month: nowDisplayMonth
                    )
                    {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        showSaveSuccess = true
                    }
                })
                { Image(systemName: "square.and.arrow.down").fontWeight(.medium) }

                NavigationLink(destination: AllCurriculumSetting())
                {
                    Image(systemName: "rectangle.stack")
                        .fontWeight(.medium)
                }
            }
        }
        .sheet(isPresented: $showSettings)
        {
            CurriculumSettingView(semesterStartDate: $semesterStartDate, courses: $courses)
                .environmentObject(userinfo)
                // 课表设置只能通过左上角叉号退出，避免下滑时绕过导入后的保存确认。
                .interactiveDismissDisabled()
        }
        .sheet(item: $editCourseContext)
        { course in
            CourseGroupEditorView(
                courses: $courses,
                mode: .edit(courseGroup(for: course))
            )
        }
        .sheet(item: $addCourseContext)
        { context in
            CourseGroupEditorView(
                courses: $courses,
                mode: .add(prefillWeekday: context.day, prefillPeriod: context.period)
            )
        }
        .onAppear
        {
            loadSavedData()
            self.nowDisplayWeek = calculateCurrentWeek()
            updateDatesForDisplayWeek()
            CurriculumNotificationManager.shared.requestPermission()
        }
        .alert("保存成功", isPresented: $showSaveSuccess)
        {
            Button("好的", role: .cancel) {}
        } message: {
            Text("已成功将本周课表保存到相册")
        }
    }

    // 页面主体

    @ViewBuilder
    private var pageBodyView: some View
    {
        ZStack(alignment: .bottom)
        {
            VStack
            {
                ScrollView
                {
                    HStack(alignment: .top, spacing: 0)
                    {
                        TimeCurriculumView(
                            fontScale: curriculumFontScale,
                            visiblePeriods: visiblePeriods
                        )
                            .frame(width: curriculumTimeColumnWidth)

                        CourseGridView(
                            courses: courses,
                            nowdisplayWeek: nowDisplayWeek,
                            fontScale: curriculumFontScale,
                            visiblePeriods: visiblePeriods,
                            onDeleteCourse: { course in
                                removeCourseOccurrence(course, in: nowDisplayWeek)
                            },
                            onEditCourse: { course in
                                editCourseContext = course
                            },
                            onLongPressEmptyCell: { dayOfWeek, period in
                                addCourseContext = AddCourseContext(day: dayOfWeek, period: period)
                            },
                            onAddCourseFromCard: { course in
                                addCourseContext = AddCourseContext(day: course.day, period: course.start)
                            },
                            onSetCoursePriority: { selectedCourse, conflictGroup in
                                setDisplayPriority(for: selectedCourse, in: conflictGroup)
                            }
                        )
                    }
                    .padding(curriculumGridPadding)
                    .padding(.bottom, 140)
                }
                .gesture(
                    DragGesture()
                        .onChanged
                        { value in
                            isDragging = true
                            dragOffset = value.translation.width * 0.5
                        }
                        .onEnded
                        { value in
                            let threshold: CGFloat = 30
                            if value.translation.width < -threshold
                            {
                                nowDisplayWeek = min(nowDisplayWeek + 1, maxWeek)
                                updateDatesForDisplayWeek()
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            }
                            else if value.translation.width > threshold
                            {
                                nowDisplayWeek = max(nowDisplayWeek - 1, minWeek)
                                updateDatesForDisplayWeek()
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            }
                            dragOffset = 0
                            isDragging = false
                        }
                )
            }

            bottomControlBar
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // 底部控制条

    @ViewBuilder
    private var bottomControlBar: some View
    {
        ZStack
        {
            // 1. 核心课表控制区
            HStack(spacing: 4)
            {
                WeekStepButton(
                    systemName: "chevron.left",
                    isDisabled: nowDisplayWeek <= minWeek
                )
                {
                    isWeekFieldFocused = false
                    inputWeek = ""
                    nowDisplayWeek -= 1
                    updateDatesForDisplayWeek()
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }

                VStack(spacing: 4)
                {
                    if courses.isEmpty
                    {
                        Text("暂无课表")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    else
                    {
                        if nowDisplayWeek >= 1
                        {
                            HStack(spacing: 2)
                            {
                                Text("第")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(appActionBlue)

                                TextField("", text: weekBinding)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 24, height: 16)
                                    .background(Color(.systemGray6))
                                    .clipShape(Capsule())
                                    .foregroundColor(appActionBlue)
                                    .focused($isWeekFieldFocused)
                                    .textFieldStyle(.plain)
                                    .toolbar
                                    {
                                        ToolbarItemGroup(placement: .keyboard)
                                        {
                                            Spacer()
                                            Button("完成")
                                            {
                                                isWeekFieldFocused = false
                                                handleWeekJump()
                                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                            }
                                            .foregroundColor(appActionBlue)
                                        }
                                    }
                                    .onTapGesture { inputWeek = "" }
                                    .onSubmit { handleWeekJump() }

                                Text("周")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(appActionBlue)
                            }
                        }
                        else
                        {
                            Text("距离开学\n还有 \(-nowDisplayWeek + 1) 周")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }

                        if nowDisplayWeek == calculateCurrentWeek()
                        {
                            Text("本周")
                                .font(.caption2)
                                .foregroundColor(appActionBlue)
                                .padding(.horizontal, 6)
                                .optionalLiquidGlass(
                                    allowsNesting: true,
                                    in: Capsule(),
                                    fallback: appActionBlue.opacity(0.05)
                                )
                        }
                    }
                }
                .frame(width: 80)

                WeekStepButton(
                    systemName: "chevron.right",
                    isDisabled: nowDisplayWeek >= maxWeek
                )
                {
                    isWeekFieldFocused = false
                    inputWeek = ""
                    nowDisplayWeek += 1
                    updateDatesForDisplayWeek()
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .curriculumGlassPanel(in: Capsule(), enabled: enableLiquidGlassEffect)
            .overlay(alignment: .trailing)
            {
                // 右侧的小尾巴：“本周” & “开学周”
                VStack(spacing: 6)
                {
                    if nowDisplayWeek != calculateCurrentWeek()
                    {
                        Button(action: {
                            nowDisplayWeek = calculateCurrentWeek()
                            updateDatesForDisplayWeek()
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        })
                        {
                            Text("本周")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                        }
                        .nativeGlassButtonStyle(prominent: true)
                        .tint(appActionBlue)
                        .controlSize(.small)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                    }

                    if nowDisplayWeek < 1
                    {
                        Button(action: {
                            nowDisplayWeek = 1
                            updateDatesForDisplayWeek()
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        })
                        {
                            Text("开学周")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                        }
                        .nativeGlassButtonStyle(prominent: true, backgroundTint: .green)
                        .tint(.green)
                        .controlSize(.small)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: nowDisplayWeek)
                .offset(x: 64)
            }

            .opacity(showBottomControls ? 1 : 0) // 不透明度渐变
            .offset(y: showBottomControls ? 0 : 80) // 向下滑出屏幕 80px
            .scaleEffect(showBottomControls ? 1 : 0.95) // 微微缩放，更有呼吸感
            .allowsHitTesting(showBottomControls) // 隐藏时禁用点击，防止“幽灵触控”
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: showBottomControls) // 显式绑定动画

            // 周数收起后仍保留系统按钮，便于重新展开。
            NextButton(
                systemImage: showBottomControls ? "chevron.down" : "chevron.up",
                tint: showBottomControls ? .secondary : appActionBlue,
                size: 32,
                prominent: false
            ) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showBottomControls.toggle()
            }
            .accessibilityLabel(showBottomControls ? "隐藏周数" : "展开周数")
            .offset(x: showBottomControls ? -130 : 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: showBottomControls)
        }
    }

    // 工具

    private func handleWeekJump()
    {
        let target = Int(inputWeek) ?? nowDisplayWeek
        nowDisplayWeek = min(max(target, 1), 30)
        updateDatesForDisplayWeek()
        inputWeek = ""
    }

    func loadSavedData()
    {
        if savedTimestamp > 0
        {
            semesterStartDate = Date(timeIntervalSince1970: savedTimestamp)
        }
        else if let sharedDate = CurriculumStore.shared.loadSemesterStartDate()
        {
            savedTimestamp = sharedDate.timeIntervalSince1970
            semesterStartDate = sharedDate
        }

        courses = CurriculumStore.shared.loadCourses()
        loadBackgroundImage()
    }

    func updateDatesForDisplayWeek()
    {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let startComps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: semesterStartDate)
        guard let firstMonday = cal.date(from: startComps) else { return }
        let offsetDays = (nowDisplayWeek - 1) * 7
        guard let targetMonday = cal.date(byAdding: .day, value: offsetDays, to: firstMonday) else { return }
        nowDisplayMonth = cal.component(.month, from: targetMonday)
        var newDates: [Int] = []
        var newWeekDates: [Date] = []
        for i in 0 ..< 7
        {
            if let date = cal.date(byAdding: .day, value: i, to: targetMonday)
            {
                newDates.append(cal.component(.day, from: date))
                newWeekDates.append(date)
            }
        }
        datesCurWeek = newDates
        weekDatesCurWeek = newWeekDates
        CurriculumWidgetSync.saveCurrentWeek(nowDisplayWeek)
    }

    func calculateCurrentWeek() -> Int
    {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let startComps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: semesterStartDate)
        guard let startMonday = cal.date(from: startComps) else { return 1 }
        let nowComps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        guard let currentMonday = cal.date(from: nowComps) else { return 1 }
        let diff = cal.dateComponents([.weekOfYear], from: startMonday, to: currentMonday)
        return (diff.weekOfYear ?? 0) + 1
    }

    /// 仅删除当前显示周的一次课程出现：
    /// - 若该课还有其他周次，保留课程并移除当前周
    /// - 若仅剩当前周，则删除整门课
    private func removeCourseOccurrence(_ course: Course, in week: Int)
    {
        guard let index = courses.firstIndex(where: { $0.id == course.id })
        else
        {
            return
        }

        let target = courses[index]

        guard target.weekList.contains(week)
        else
        {
            // 兜底：如果未命中周次，按旧逻辑整门删除
            courses.remove(at: index)
            saveCourses()
            return
        }

        let newWeekList = target.weekList.filter { $0 != week }

        if newWeekList.isEmpty
        {
            courses.remove(at: index)
        }
        else
        {
            let updatedCourse = Course(
                id: target.id,
                name: target.name,
                shortName: target.shortName,
                day: target.day,
                start: target.start,
                step: target.step,
                room: target.room,
                teacher: target.teacher,
                weekList: newWeekList,
                weeks: weekText(from: newWeekList),
                term: target.term,
                colorRandom: target.colorRandom,
                customColorHex: target.customColorHex,
                isManual: target.isManual,
                assessmentMethod: target.assessmentMethod,
                priority: target.priority,
                courseType: target.courseType
            )
            courses[index] = updatedCourse
        }

        saveCourses()
    }

    private func weekText(from weekList: [Int]) -> String
    {
        weekList.sorted().map { "\($0)" }.joined(separator: ",") + "周"
    }
}

extension CurriculumView
{
    private func loadBackgroundImage()
    {
        backgroundImage = BackgroundImageStore.loadImage(named: backgroundImageFilename)
    }
}
