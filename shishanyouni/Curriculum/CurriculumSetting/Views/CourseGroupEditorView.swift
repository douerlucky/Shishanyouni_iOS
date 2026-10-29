import SwiftUI

struct CourseGroupEditorView: View
{
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var iapStore: IAPStore
    @Binding var courses: [Course]

    let mode: CourseGroupEditorMode

    @State private var courseName = ""
    @State private var courseShortName = ""
    @State private var location = ""
    @State private var teacherName = ""
    @State private var assessmentMethod = ""
    @State private var courseType: CurriculumCourseType = .regular
    @State private var selectedColor: Color = .blue
    @State private var hasCustomColor = false
    @State private var timeSlots: [CourseTimeSlotDraft]
    @State private var weekPickerSlotID: UUID?
    @State private var pendingDeleteSlotID: UUID?
    @State private var showSubscription = false
    @AppStorage(PreferenceKey.showCampusPassFeatures) private var showCampusPassFeatures = true

    private let weekdays = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
    /// 与课表网格共用同一顺序：1–4 节后显示中午，5–8 节后显示晚上。
    private let periods = CurriculumClassSchedule.displayOrder

    init(courses: Binding<[Course]>, mode: CourseGroupEditorMode)
    {
        _courses = courses
        self.mode = mode

        switch mode
        {
        case let .add(weekday, period):
            _timeSlots = State(
                initialValue: [
                    CourseTimeSlotDraft(
                        weekday: weekday,
                        startPeriod: period,
                        endPeriod: CurriculumClassSchedule.defaultEndPeriod(for: period),
                        weeks: Set(1 ... 20)
                    )
                ]
            )

        case let .edit(group):
            _courseType = State(initialValue: group.courseType)
            _courseName = State(initialValue: group.name)
            _courseShortName = State(initialValue: group.courses.first?.shortName ?? "")
            _location = State(initialValue: group.room ?? "")
            _teacherName = State(initialValue: group.teacher ?? "")
            _assessmentMethod = State(initialValue: group.assessmentMethod ?? "")
            _timeSlots = State(initialValue: group.courses.map(CourseTimeSlotDraft.init))

            if let hex = group.courses.first?.customColorHex,
               let color = Color(hex: hex)
            {
                _selectedColor = State(initialValue: color)
                _hasCustomColor = State(initialValue: true)
            }
        }
    }

    var body: some View
    {
        NavigationStack
        {
            Form
            {
                Section("课程信息")
                {
                    TextField("课程名称", text: $courseName)

                    Picker("课程类型", selection: $courseType)
                    {
                        ForEach(CurriculumCourseType.allCases) { type in Text(type.title).tag(type) }
                    }

                    if showCampusPassFeatures
                    {
                        abbreviationEditor
                    }

                    TextField("教室（可选）", text: $location)
                    TextField("教师（可选）", text: $teacherName)

                    Picker("课程考查形式", selection: $assessmentMethod)
                    {
                        Text("未指定").tag("")
                        Text("考查").tag("考查")
                        Text("考试").tag("考试")
                    }

                    HStack
                    {
                        Text("课程颜色")
                        Spacer()

                        if hasCustomColor
                        {
                            Button("重置") { hasCustomColor = false }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        ColorPicker(
                            "课程颜色",
                            selection: $selectedColor,
                            supportsOpacity: false
                        )
                        .labelsHidden()
                        .onChange(of: selectedColor)
                        { _ in
                            hasCustomColor = true
                        }
                    }
                }

                Section(courseType == .regular ? "上课时间段" : "课程周次")
                {
                    ForEach($timeSlots)
                    { $slot in
                        timeSlotEditor(slot: $slot)
                    }

                    Button
                    {
                        addTimeSlot()
                    }
                    label:
                    {
                        Label(courseType == .regular ? "添加时间段" : "添加周次安排", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar
            {
                ToolbarItem(placement: .cancellationAction)
                {
                    Button("取消") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction)
                {
                    Button(mode.buttonTitle)
                    {
                        saveCourseGroup()
                    }
                    .disabled(!isFormValid)
                }
            }
            .sheet(isPresented: weekPickerIsPresented)
            {
                if let slotID = weekPickerSlotID
                {
                    CourseWeekPickerSheet(selectedWeeks: weeksBinding(for: slotID))
                }
            }
            .alert("删除时间段", isPresented: deleteSlotAlertIsPresented)
            {
                Button("取消", role: .cancel)
                {
                    pendingDeleteSlotID = nil
                }

                Button(deleteConfirmationTitle, role: .destructive)
                {
                    deleteSelectedTimeSlot()
                }
            }
            message:
            {
                Text(deleteConfirmationMessage)
            }
            .sheet(isPresented: $showSubscription)
            {
                SubscriptionView()
            }
        }
    }

    /// 未开通时仍显示一个可点击的入口，避免把付费功能伪装成不可用的普通输入框。
    @ViewBuilder
    private var abbreviationEditor: some View
    {
        if iapStore.hasActiveSubscription
        {
            TextField("课程简称（可选）", text: $courseShortName)

            Text("填写后，课表、提醒和小组件将优先显示简称；留空则显示完整课程名。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        else
        {
            Button
            {
                showSubscription = true
            }
            label:
            {
                HStack
                {
                    Label("课程简称", systemImage: "lock.fill")
                    Spacer()
                    Text("校园通行证")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
            }
            .foregroundStyle(.primary)
        }
    }

    @ViewBuilder
    private func timeSlotEditor(slot: Binding<CourseTimeSlotDraft>) -> some View
    {
        let number = (timeSlots.firstIndex { $0.id == slot.wrappedValue.id } ?? 0) + 1

        VStack(alignment: .leading, spacing: 16)
        {
            HStack
            {
                Label(courseType == .regular ? "时间段 \(number)" : "周次安排 \(number)",
                      systemImage: courseType == .regular ? "clock.fill" : "calendar")
                    .font(.headline)

                Spacer()

                // 新建课程至少保留一个时间段；已有课程的最后一段则会升级为“删除整门课程”。
                if timeSlots.count > 1 || existingGroup != nil
                {
                    Button(role: .destructive)
                    {
                        pendingDeleteSlotID = slot.wrappedValue.id
                    }
                    label:
                    {
                        Image(systemName: "trash")
                    }
                    .nativeGlassButtonStyle()
                    .tint(.red)
                    .controlSize(.small)
                }
            }

            if courseType == .regular
            {
                HStack(spacing: 10)
                {
                    timeMenu(title: "星期", value: weekdays[slot.wrappedValue.weekday - 1])
                    {
                        ForEach(1 ... 7, id: \.self)
                        { day in
                            Button(weekdays[day - 1])
                            {
                                slot.wrappedValue.weekday = day
                            }
                        }
                    }

                    timeMenu(
                        title: "开始节次",
                        value: CurriculumClassSchedule.displayName(for: slot.wrappedValue.startPeriod)
                    )
                    {
                        ForEach(periods, id: \.self)
                        { period in
                            Button(CurriculumClassSchedule.displayName(for: period))
                            {
                                updateStartPeriod(period, for: slot)
                            }
                        }
                    }

                    timeMenu(
                        title: "结束节次",
                        value: CurriculumClassSchedule.displayName(for: slot.wrappedValue.endPeriod)
                    )
                    {
                        ForEach(
                            CurriculumClassSchedule.validEndPeriods(
                                for: slot.wrappedValue.startPeriod
                            ),
                            id: \.self
                        )
                        { period in
                            Button(CurriculumClassSchedule.displayName(for: period))
                            {
                                slot.wrappedValue.endPeriod = period
                            }
                        }
                    }
                }
            }

            Button
            {
                weekPickerSlotID = slot.wrappedValue.id
            }
            label:
            {
                HStack(spacing: 12)
                {
                    VStack(alignment: .leading, spacing: 3)
                    {
                        Text(courseType == .regular ? "上课周次" : "课程周次")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(slot.wrappedValue.weeksText)
                            .font(.body.weight(.medium))
                            .lineLimit(1)
                            .foregroundStyle(.primary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 40)
                .contentShape(Rectangle())
            }
            .nativeGlassButtonStyle(shape: .roundedRectangle, fillsWidth: true)

            if courseType == .regular && !CurriculumClassSchedule.isValidCourseRange(
                start: slot.wrappedValue.startPeriod,
                end: slot.wrappedValue.endPeriod
            )
            {
                Text("中午和晚上时段只能单独选择")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }

    /// 用系统 Menu 提供明确的可点击时段选择控件。
    private func timeMenu<Content: View>(
        title: String,
        value: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View
    {
        Menu(content: content)
        {
            VStack(alignment: .leading, spacing: 3)
            {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4)
                {
                    Text(value)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .contentShape(Rectangle())
        }
        .nativeGlassButtonStyle(shape: .roundedRectangle, fillsWidth: true)
    }

    /// 开始节次变更时，保证结束节次仍处于允许范围。
    private func updateStartPeriod(
        _ period: Int,
        for slot: Binding<CourseTimeSlotDraft>
    )
    {
        slot.wrappedValue.startPeriod = period

        let validEnds = CurriculumClassSchedule.validEndPeriods(for: period)
        if !validEnds.contains(slot.wrappedValue.endPeriod)
        {
            slot.wrappedValue.endPeriod = CurriculumClassSchedule.defaultEndPeriod(for: period)
        }
    }

    private var isFormValid: Bool
    {
        !courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !timeSlots.isEmpty
            && timeSlots.allSatisfy
            {
                (courseType == .other || CurriculumClassSchedule.isValidCourseRange(
                    start: $0.startPeriod,
                    end: $0.endPeriod
                )) && !$0.weeks.isEmpty
            }
    }

    private var weekPickerIsPresented: Binding<Bool>
    {
        Binding(
            get: { weekPickerSlotID != nil },
            set: { isPresented in
                if !isPresented
                {
                    weekPickerSlotID = nil
                }
            }
        )
    }

    private var deleteSlotAlertIsPresented: Binding<Bool>
    {
        Binding(
            get: { pendingDeleteSlotID != nil },
            set: { isPresented in
                if !isPresented
                {
                    pendingDeleteSlotID = nil
                }
            }
        )
    }

    private var deleteConfirmationTitle: String
    {
        timeSlots.count == 1 && existingGroup != nil ? "删除整门课程" : "删除"
    }

    private var deleteConfirmationMessage: String
    {
        if timeSlots.count == 1
        {
            return existingGroup == nil
                ? "新课程至少需要保留一个时间段。"
                : "这是最后一个时间段，删除后将删除整门课程和该课程的提醒。"
        }

        return "将删除这个时间段；其他时间段和提醒不受影响。"
    }

    private var existingGroup: CourseGroup?
    {
        guard case let .edit(group) = mode else { return nil }
        return group
    }

    private func weeksBinding(for slotID: UUID) -> Binding<Set<Int>>
    {
        Binding(
            get:
            {
                timeSlots.first(where: { $0.id == slotID })?.weeks ?? []
            },
            set:
            {
                guard let index = timeSlots.firstIndex(where: { $0.id == slotID })
                else { return }
                timeSlots[index].weeks = $0
            }
        )
    }

    private func addTimeSlot()
    {
        let reference = timeSlots.last
        let start = reference.flatMap
        { CurriculumClassSchedule.nextDisplayPeriod(after: $0.endPeriod) } ?? 1

        timeSlots.append(
            CourseTimeSlotDraft(
                weekday: reference?.weekday ?? 1,
                startPeriod: start,
                endPeriod: CurriculumClassSchedule.defaultEndPeriod(for: start),
                weeks: reference?.weeks ?? Set(1 ... 20)
            )
        )
    }

    private func deleteSelectedTimeSlot()
    {
        guard let slotID = pendingDeleteSlotID else { return }
        pendingDeleteSlotID = nil

        // 新建模式不能留下一个空的课程表单；用户可直接取消返回。
        guard timeSlots.count > 1 else
        {
            if existingGroup != nil
            {
                deleteEntireCourseGroup()
            }
            return
        }

        timeSlots.removeAll { $0.id == slotID }
    }

    private func deleteEntireCourseGroup()
    {
        guard let group = existingGroup else { return }

        let reminderIDs = Set(group.courses.map(\.id))
        CurriculumNotificationManager.shared.removeReminderPreferences(for: reminderIDs)
        courses.removeAll { CourseGroupKey(course: $0) == group.id }
        persistCourses()
        dismiss()
    }

    private func saveCourseGroup()
    {
        let name = courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        // 未开通时不允许新增或修改简称，但保留用户此前已保存的数据。
        let shortName = iapStore.hasActiveSubscription
            ? normalizedOptionalText(courseShortName)
            : existingGroup?.courses.first?.shortName
        let room = normalizedOptionalText(location)
        let teacher = normalizedOptionalText(teacherName)
        let customColorHex = hasCustomColor ? selectedColor.toHex() : nil
        let originalCourses = existingGroup?.courses ?? []
        let colorRandom = originalCourses.first?.colorRandom ?? Int.random(in: 0 ... 31)
        let term = originalCourses.first?.term

        let retainedSources = timeSlots.compactMap(\.source)
        let removedReminderIDs = Set(
            originalCourses
                .filter
                { original in
                    !retainedSources.contains(where: { $0.matchesStoredRecord(original) })
                }
                .map(\.id)
        )
        CurriculumNotificationManager.shared.removeReminderPreferences(for: removedReminderIDs)

        // 先删掉原组的扁平记录，再把每个时间段重新写回。
        // 保留的时间段沿用原 id，因此它的提醒开关、优先级都不会串到别的时间段。
        courses.removeAll
        { storedCourse in
            originalCourses.contains(where: { $0.matchesStoredRecord(storedCourse) })
        }

        let updatedCourses = timeSlots.map
        { slot in
            let weeks = slot.weeks.sorted()
            let source = slot.source

            return Course(
                id: source?.id ?? "manual_\(UUID().uuidString)",
                name: name,
                shortName: shortName,
                day: courseType == .regular ? slot.weekday : 0,
                start: courseType == .regular ? slot.startPeriod : 0,
                step: courseType == .regular ? slot.endPeriod - slot.startPeriod + 1 : 0,
                room: room,
                teacher: teacher,
                weekList: weeks,
                weeks: weeks.map(String.init).joined(separator: ",") + "周",
                term: source?.term ?? term,
                colorRandom: colorRandom,
                customColorHex: customColorHex,
                isManual: source?.isManual ?? true,
                // 考查形式属于整门课程，所有时间段保持一致。
                assessmentMethod: normalizedOptionalText(assessmentMethod),
                priority: source?.priority,
                courseType: courseType
            )
        }

        courses.append(contentsOf: updatedCourses)

        // 用户确认“同名课程同色”：即使教室或老师不同，也同步颜色。
        for index in courses.indices where courses[index].name == name
        {
            courses[index].colorRandom = colorRandom
            courses[index].customColorHex = customColorHex
        }

        persistCourses()
        dismiss()
    }

    private func normalizedOptionalText(_ text: String) -> String?
    {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func persistCourses()
    {
        CurriculumStore.shared.saveCourses(courses, semesterStart: nil)
        CurriculumNotificationManager.shared.rescheduleAllNotifications()
    }
}

private extension Course
{
    /// 用所有决定一条扁平记录身份的字段定位旧数据。
    /// 不能只用 id：历史版本中可能存有相同 id 的不同时间段。
    func matchesStoredRecord(_ other: Course) -> Bool
    {
        id == other.id
            && name == other.name
            && day == other.day
            && start == other.start
            && step == other.step
            && room == other.room
            && teacher == other.teacher
            && weekList == other.weekList
            && term == other.term
            && courseType == other.courseType
    }
}
