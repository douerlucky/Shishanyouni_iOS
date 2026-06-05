//
//  CourseDetailView.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/15.
//

import SwiftUI

struct CourseDetailView: View
{
    let course: CourseInfo
    @EnvironmentObject var userinfo: userInfo
    @State private var groupedClasses: [String: [CourseClassInfo]] = [:]
    @State private var isLoading = true
    @State private var showAddAlert = false
    @State private var addAlertMessage = ""
    @State private var showMFASheet = false
    @State private var mfaMaskedPhone = ""
    @State private var mfaCode = ""
    @State private var mfaContinuation: CheckedContinuation<String?, Never>?
    @State private var mfaSendCodeAction: (() async -> String?)?

    private let scheduleQuery = ScheduleQuery()

    var body: some View
    {
        ZStack
        {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

            if isLoading
            {
                VStack
                {
                    ProgressView()
                    Text("正在拉取教学班信息...").font(.caption).foregroundColor(.secondary).padding(.top, 8)
                }
            }
            else if groupedClasses.isEmpty
            {
                VStack(spacing: 20)
                {
                    Image(systemName: "info.circle")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    VStack(spacing: 8)
                    {
                        Text("无班级详情")
                            .font(.headline)
                        Text("该课程在该学期可能暂无安排")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            else
            {
                ScrollView
                {
                    VStack(spacing: 16)
                    {
                        // 顶部课程简报
                        VStack(alignment: .leading, spacing: 8)
                        {
                            Text(course.kcmc)
                                .font(.title2.bold())
                                .textSelection(.enabled)
                            HStack
                            {
                                if course.querySource == .cas, let displayCode = course.displayCode
                                {
                                    Text(displayCode)
                                        .monospaced()
                                        .foregroundColor(.secondary)
                                        .textSelection(.enabled)
                                }
                                Text(course.kkbmmc ?? course.teacherName ?? "未知单位")
                                    .foregroundColor(.secondary)
                            }
                            .font(.subheadline)
                            if course.querySource == .shishanyouni
                            {
                                if let className = course.className, !className.isEmpty
                                {
                                    Text(className)
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)

                        // 教学班列表 (按 jxb_id 分组)
                        ForEach(groupedClasses.keys.sorted(), id: \.self)
                        { jxbId in
                            if let classInfos = groupedClasses[jxbId], let first = classInfos.first
                            {
                                ClassGroupCard(
                                    jxbmc: first.jxbmc,
                                    infos: classInfos,
                                    showHeader: course.querySource == .cas,
                                    onAddToSchedule: { infos in
                                        addToSchedule(infos)
                                    }
                                )
                                    .padding(.horizontal)
                            }
                        }

                        Spacer(minLength: 30)
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("课程详情")
        .navigationBarTitleDisplayMode(.automatic)
        .onAppear
        {
            fetchData()
        }
        .alert("添加到课表", isPresented: $showAddAlert)
        {
            Button("好的", role: .cancel) {}
        } message: {
            Text(addAlertMessage)
        }
        .sheet(isPresented: $showMFASheet)
        {
            MFACodeInputSheet(
                maskedPhone: mfaMaskedPhone,
                code: $mfaCode,
                onSendCode: $mfaSendCodeAction,
                onCancel: { resolveMFACode(nil) },
                onConfirm: { resolveMFACode(mfaCode.trimmingCharacters(in: .whitespacesAndNewlines)) }
            )
        }
    }

    private func fetchData()
    {
        Task
        {
            do
            {
                let results: [CourseClassInfo]
                switch course.querySource
                {
                case .cas:
                    let cookie = try await scheduleQuery.loginAndGetCookie(
                        username: userinfo.username,
                        rsaPassword: userinfo.encryptedPasswordSchool,
                        mfaCodeProvider: { phone in
                            await requestMFACode(maskedPhone: phone)
                        }
                    )
                    results = try await AllCourseQuery.shared.fetchCourseClasses(
                        cookie: cookie,
                        xnm: course.xnm,
                        xqm: course.xqm,
                        kch_id: course.kch_id
                    )
                case .shishanyouni:
                    guard let classCode = course.classCode, !classCode.isEmpty else
                    {
                        throw AllCourseQueryError.apiError("缺少 classCode，无法查询狮山有你课程详情。")
                    }
                    results = try await fetchLionCourseClassesWithMFA(classCode: classCode)
                }

                await MainActor.run
                {
                    // 根据 jxb_id 分类
                    self.groupedClasses = Dictionary(grouping: results, by: { $0.jxb_id })
                    self.isLoading = false
                }
            }
            catch
            {
                print("详情查询失败: \(error)")
                await MainActor.run { self.isLoading = false }
            }
        }
    }

    private func addToSchedule(_ infos: [CourseClassInfo])
    {
        let parsedCourses = infos.compactMap { makeScheduleCourse(from: $0) }
        guard !parsedCourses.isEmpty
        else
        {
            addAlertMessage = "这个教学班的星期、节次或周次解析失败，暂时不能加入课表。"
            showAddAlert = true
            return
        }

        var savedCourses = CurriculumStore.shared.loadCourses()
        let coursesToAdd = parsedCourses.filter
        { newCourse in
            !savedCourses.contains(where: { isSameScheduleCourse($0, newCourse) })
        }

        guard !coursesToAdd.isEmpty else
        {
            addAlertMessage = "这个教学班已经在课表里啦。"
            showAddAlert = true
            return
        }

        savedCourses.append(contentsOf: coursesToAdd)
        CurriculumStore.shared.saveCourses(savedCourses, semesterStart: nil)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        addAlertMessage = "已添加「\(course.kcmc)」的 \(coursesToAdd.count) 条上课安排到课表。"
        showAddAlert = true
    }

    private func makeScheduleCourse(from info: CourseClassInfo) -> Course?
    {
        guard let day = resolvedDay(for: info),
              let periods = resolvedPeriods(for: info)
        else { return nil }

        let weekNumbers = resolvedWeeks(for: info)
        guard !weekNumbers.isEmpty else { return nil }

        let weekList = Array(weekNumbers).sorted()
        return Course(
            id: "rub_\(UUID().uuidString)",
            name: course.kcmc,
            day: day,
            start: periods.lowerBound,
            step: periods.upperBound - periods.lowerBound + 1,
            room: normalizedOptional(info.cdmc),
            teacher: normalizedOptional(info.xm ?? course.teacherName),
            weekList: weekList,
            weeks: normalizedOptional(info.zcd) ?? weekText(from: weekList),
            term: "\(course.xnm)-\(course.xqm)",
            colorRandom: stableColorIndex(for: course.kcmc),
            customColorHex: nil,
            isManual: true
        )
    }

    private func resolvedDay(for info: CourseClassInfo) -> Int?
    {
        if let dayNumber = info.dayNumber { return dayNumber }
        guard let text = info.xqjmc else { return nil }
        if text.contains("一") { return 1 }
        if text.contains("二") { return 2 }
        if text.contains("三") { return 3 }
        if text.contains("四") { return 4 }
        if text.contains("五") { return 5 }
        if text.contains("六") { return 6 }
        if text.contains("日") || text.contains("天") { return 7 }
        return nil
    }

    private func resolvedPeriods(for info: CourseClassInfo) -> ClosedRange<Int>?
    {
        if let start = info.startPeriod, let end = info.endPeriod
        {
            return start ... end
        }

        guard let text = info.jc else { return nil }
        let numbers = extractNumbers(from: text)
        guard let first = numbers.first else { return nil }
        return first ... (numbers.dropFirst().first ?? first)
    }

    private func resolvedWeeks(for info: CourseClassInfo) -> Set<Int>
    {
        if let weekNumbers = info.weekNumbers, !weekNumbers.isEmpty
        {
            return Set(weekNumbers)
        }
        return parseWeeks(from: info.zcd ?? "")
    }

    private func parseWeeks(from text: String) -> Set<Int>
    {
        var result = Set<Int>()
        let segments = text.replacingOccurrences(of: "，", with: ",").split(separator: ",")
        for rawSegment in segments
        {
            let segment = String(rawSegment)
            let numbers = extractNumbers(from: segment)
            guard let first = numbers.first else { continue }
            let isEven = segment.contains("双")
            let isOdd = segment.contains("单")

            if let last = numbers.dropFirst().first
            {
                for week in first ... last where (!isEven || week % 2 == 0) && (!isOdd || week % 2 == 1)
                {
                    result.insert(week)
                }
            }
            else if (!isEven || first % 2 == 0) && (!isOdd || first % 2 == 1)
            {
                result.insert(first)
            }
        }
        return result
    }

    private func extractNumbers(from text: String) -> [Int]
    {
        let regex = try? NSRegularExpression(pattern: #"\d+"#)
        let range = NSRange(text.startIndex ..< text.endIndex, in: text)
        return regex?.matches(in: text, range: range).compactMap
        { match in
            guard let swiftRange = Range(match.range, in: text) else { return nil }
            return Int(text[swiftRange])
        } ?? []
    }

    private func normalizedOptional(_ value: String?) -> String?
    {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }

    private func weekText(from weekList: [Int]) -> String
    {
        weekList.sorted().map { "\($0)" }.joined(separator: ",") + "周"
    }

    private func stableColorIndex(for name: String) -> Int
    {
        name.unicodeScalars.reduce(0) { ($0 * 31 + Int($1.value)) % 32 }
    }

    private func isSameScheduleCourse(_ lhs: Course, _ rhs: Course) -> Bool
    {
        lhs.name == rhs.name
            && lhs.day == rhs.day
            && lhs.start == rhs.start
            && lhs.step == rhs.step
            && lhs.room == rhs.room
            && lhs.teacher == rhs.teacher
            && lhs.weekList == rhs.weekList
    }
}

extension CourseDetailView
{
    private func fetchLionCourseClassesWithMFA(classCode: String) async throws -> [CourseClassInfo]
    {
        do
        {
            return try await AllCourseQuery.shared.fetchLionCourseClasses(classCode: classCode)
        }
        catch ShishanyouniAPIError.needMFA(let phone, let sessionId, _)
        {
            try await refreshShishanyouniToken(phone: phone, sessionId: sessionId)
            return try await AllCourseQuery.shared.fetchLionCourseClasses(classCode: classCode)
        }
    }

    private func refreshShishanyouniToken(phone: String, sessionId: String) async throws
    {
        guard let smsCode = await requestShishanyouniMFACode(maskedPhone: phone, sessionId: sessionId),
              !smsCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else
        {
            throw ShishanyouniAPIError.apiError(code: 22, message: "已取消短信验证码验证。")
        }

        let token = try await ShishanyouniMFAFlow.submitCode(sessionId: sessionId, smsCode: smsCode)
        await MainActor.run
        {
            userinfo.updateShishanyouniToken(token)
        }
    }

    @MainActor
    private func requestMFACode(maskedPhone: String?) async -> String?
    {
        mfaMaskedPhone = maskedPhone ?? ""
        mfaCode = ""
        mfaSendCodeAction = MFACodeContext.activeSendCodeAction
        await Task.yield()
        showMFASheet = true
        return await withCheckedContinuation
        { continuation in
            mfaContinuation = continuation
        }
    }

    @MainActor
    private func requestShishanyouniMFACode(maskedPhone: String, sessionId: String) async -> String?
    {
        mfaMaskedPhone = maskedPhone
        mfaCode = ""
        mfaSendCodeAction = { await ShishanyouniMFAFlow.sendCodeMessage(sessionId: sessionId) }
        await Task.yield()
        showMFASheet = true
        return await withCheckedContinuation
        { continuation in
            mfaContinuation = continuation
        }
    }

    @MainActor
    private func resolveMFACode(_ code: String?)
    {
        showMFASheet = false
        mfaContinuation?.resume(returning: code)
        mfaContinuation = nil
        mfaSendCodeAction = nil
    }
}

// MARK: - 教学班分组卡片视图

struct ClassGroupCard: View
{
    let jxbmc: String
    let infos: [CourseClassInfo]
    let showHeader: Bool
    let onAddToSchedule: ([CourseClassInfo]) -> Void

    var body: some View
    {
        VStack(alignment: .leading, spacing: 0)
        {
            // Header: 教学班名称和选课人数
            if showHeader
            {
                HStack
                {
                    Text(jxbmc)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.blue)
                    Spacer()
                }
                .padding()
                .background(Color.blue.opacity(0.05))
            }

            HStack(alignment: .center, spacing: 12)
            {
                VStack(alignment: .leading, spacing: 8)
                {
                    // 教师信息
                    if let teacher = infos.first?.xm
                    {
                        HStack(spacing: 8)
                        {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.blue)
                            Text(teacher)
                                .font(.system(size: 16, weight: .medium))
                            if let title = infos.first?.zcmc
                            {
                                Text(title)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // 开课班级
                    if let composition = infos.first?.jxbzc
                    {
                        HStack(spacing: 6)
                        {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 10, weight: .bold))

                            Text(composition)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .foregroundColor(.secondary)
                        .background(
                            Capsule()
                                .fill(Color.secondary.opacity(0.1))
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: { onAddToSchedule(infos) })
                {
                    Label("添加到课表", systemImage: "plus.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 8)

            // 具体安排列表
            VStack(alignment: .leading, spacing: 8)
            {
                ForEach(infos)
                { info in
                    HStack(alignment: .top, spacing: 8)
                    {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)

                        VStack(alignment: .leading, spacing: 2)
                        {
                            Text("\(info.xqjmc ?? "") \(info.jc ?? "")")
                                .font(.system(size: 14, weight: .semibold))

                            HStack(spacing: 10)
                            {
                                Label(info.cdmc ?? "未知地点", systemImage: "mappin.and.ellipse")
                                Label(info.zcd ?? "未知周次", systemImage: "calendar.badge.clock")
                            }
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 15)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}
