//
//  ChooseCourseView.swift
//  shishanyouni
//
//  选课页面的流程编排：类别浏览 → 触底分页 → 判断教学班层级 → 用户确认一次写请求 → 回查反馈。
//

import SwiftUI
import UIKit

struct ChooseCourseView: View
{
    @EnvironmentObject var userinfo: userInfo
    @EnvironmentObject var iapStore: IAPStore

    @State private var selectedCourses: [SelectedCourse] = []
    @State private var selectedCoursesError: String?
    @State private var isLoadingSelectedCourses = false
    @State private var catalogCategory: CourseCatalogCategory = .major
    @State private var catalogCourses: [CourseSearchResult] = []
    @State private var catalogError: String?
    @State private var catalogLoadMoreError: String?
    @State private var isLoadingCatalog = false
    @State private var isLoadingMoreCatalog = false
    @State private var catalogHasMore = false
    @State private var catalogNextRangeStart = 1
    @State private var catalogOverview = CourseSelectionOverview.empty
    @State private var selectedCourseOverview = CourseSelectionOverview.empty
    /// 系统导航搜索栏的输入和已经提交给教务系统的关键词分开保存，避免每敲一个字就发请求。
    @State private var catalogSearchText = ""
    @State private var appliedCatalogSearch = ""
    /// 同一时刻只展开一张课程卡片；教学班详情仅在本次 Cookie 生命周期内缓存。
    @State private var expandedCourseKey: String?
    @State private var expandedTeachingClasses: [String: [CourseSearchResult]] = [:]
    @State private var expandingCourseKey: String?
    @State private var expandedCourseError: String?
    /// 目录里的教学班 token 只和本次登录会话绑定，切换类别仍可复用同一 Cookie。
    @State private var catalogCookie: String?
    @State private var catalogRequestID = UUID()
    @State private var isPreparingSelection = false
    @State private var isMutatingCourse = false
    @State private var semester = SelectedCourseSemester.current()

    @State private var showSelectedCourses = false
    @State private var parentSelectionState: ParentSelectionState?
    /// 主教学班 Sheet 关闭完成前先暂存选择，避免紧接着展示子教学班 Sheet。
    @State private var pendingSelectionAfterParentSheet: PendingParentSelection?
    @State private var childSelectionState: ChildSelectionState?
    /// 子班 Sheet 关闭完成前先暂存选择，onDismiss 后再提交，避免请求和浮层关闭抢时序。
    @State private var pendingSelectionAfterChildSheet: PendingSelection?
    /// 选课确认和结果反馈共用一个 Alert 容器，避免多个 Alert 修饰器互相覆盖。
    @State private var activeAlert: CourseActionAlert?

    @State private var showMFASheet = false
    @State private var mfaMaskedPhone = ""
    @State private var mfaCode = ""
    @State private var mfaContinuation: CheckedContinuation<String?, Never>?
    @State private var mfaSendCodeAction: (() async -> String?)?

    private let scheduleQuery = ScheduleQuery()

    /// 全屏流程（首次加载、读取教学班、提交选课）统一在页面中心提示，避免加载框跟随列表滚动到顶部。
    private var loadingOverlayMessage: String?
    {
        if isMutatingCourse
        {
            return "正在提交一次请求并核验结果…"
        }
        if isPreparingSelection
        {
            return "正在读取教学班…"
        }
        if expandingCourseKey != nil
        {
            return "正在读取当前教学班…"
        }
        if isLoadingCatalog, catalogCourses.isEmpty
        {
            return "正在加载课程…"
        }
        return nil
    }

    var body: some View
    {
        Group
        {
            if iapStore.hasActiveSubscription
            {
                courseSelectionContent
            }
            else
            {
                // 首页入口之外的跳转也必须经过这里，避免直接导航绕过校园通行证。
                SubscriptionView()
            }
        }
    }

    /// 订阅有效时才创建课程目录和教务请求流程，未开通时不会偷偷读取选课数据。
    private var courseSelectionContent: some View
    {
        ZStack
        {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            List
            {
                Text("本功能还在测试阶段，不能代替教务系统进行选课。请以教务系统显示的信息为准；因没选上、错选或漏选造成的一切后果，开发者不承担责任。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 2, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                CourseCatalogView(
                    category: $catalogCategory,
                    semester: semester,
                    overview: catalogOverview,
                    appliedSearchText: appliedCatalogSearch,
                    courses: catalogCourses,
                    isLoading: isLoadingCatalog,
                    isLoadingMore: isLoadingMoreCatalog,
                    hasMore: catalogHasMore,
                    errorMessage: catalogError,
                    loadMoreError: catalogLoadMoreError,
                    expandedCourseKey: expandedCourseKey,
                    expandedTeachingClasses: expandedTeachingClasses,
                    expandingCourseKey: expandingCourseKey,
                    expandedCourseError: expandedCourseError,
                    onRetry: { Task { await reloadCatalog() } },
                    onReachEnd: { loadMoreCatalog() },
                    onToggleExpansion: toggleCourseExpansion,
                    onRetryExpansion: retryCourseExpansion,
                    onSelectTeachingClass: beginSelection,
                    selectedCourseFor: selectedCourse(for:),
                    onRequestDrop: requestDropConfirmation
                )
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .refreshable { await reloadCatalog() }
            .disabled(isMutatingCourse || isPreparingSelection)

            if let loadingOverlayMessage
            {
                CourseCenteredLoadingOverlay(message: loadingOverlayMessage)
            }
        }
        .navigationTitle("选课")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $catalogSearchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "搜索课程名称或课程号"
        )
        .onSubmit(of: .search)
        {
            submitCatalogSearch()
        }
        .onChange(of: catalogSearchText)
        { newValue in
            // 系统搜索框点清除后立即恢复该分类的完整目录，不保留已经提交的旧关键词。
            if newValue.isEmpty, !appliedCatalogSearch.isEmpty
            {
                clearCatalogSearch()
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .toolbar
        {
            ToolbarItem(placement: .topBarTrailing)
            {
                Button
                {
                    showSelectedCourses = true
                } label: {
                    Image(systemName: "rectangle.stack.fill")
                }
                .disabled(isMutatingCourse || isPreparingSelection)
                .accessibilityLabel("已选科目")
            }
        }
        .task
        {
            if catalogCourses.isEmpty, !isLoadingCatalog
            {
                ChooseCourseDebug.info("选课页首次出现，开始加载主修课程目录")
                await reloadCatalog()
            }
        }
        .onChange(of: catalogCategory)
        { _ in
            categoryDidChange()
        }
        .navigationDestination(isPresented: $showSelectedCourses)
        {
            SelectedCourseListScreen(
                courses: selectedCourses,
                semester: semester,
                overview: selectedCourseOverview,
                isLoading: isLoadingSelectedCourses,
                errorMessage: selectedCoursesError,
                onRetry: { Task { await loadSelectedCourses() } },
                onRefresh: { await loadSelectedCourses() },
                onDrop: requestDropConfirmation
            )
        }
        .sheet(item: $parentSelectionState, onDismiss: submitPendingSelectionAfterParentSheet)
        { state in
            ParentCoursePickerSheet(
                course: state.course,
                parentClasses: state.parentClasses,
                onSelect: { parentClass in
                    ChooseCourseDebug.info("用户在主教学班 Sheet 选择了一个选项，等待 Sheet 完全关闭后继续")
                    pendingSelectionAfterParentSheet = PendingParentSelection(
                        course: parentClass,
                        cookie: state.cookie,
                        semester: state.semester
                    )
                    parentSelectionState = nil
                }
            )
        }
        .sheet(item: $childSelectionState, onDismiss: submitPendingSelectionAfterChildSheet)
        { state in
            ChildCoursePickerSheet(
                course: state.course,
                childClasses: state.childClasses,
                onSelect: { childClass in
                    ChooseCourseDebug.info("用户在子教学班 Sheet 选择了一个选项，等待 Sheet 完全关闭后提交选课")
                    pendingSelectionAfterChildSheet = PendingSelection(
                        course: state.course,
                        childClass: childClass,
                        cookie: state.cookie,
                        semester: state.semester
                    )
                    childSelectionState = nil
                }
            )
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
        .alert(item: $activeAlert, content: alertContent)
    }

    /// 选中子班本身就是用户的选课确认；`onDismiss` 时 Sheet 已真正离场，再提交即可稳定反馈结果。
    @MainActor
    private func submitPendingSelectionAfterChildSheet()
    {
        guard let pending = pendingSelectionAfterChildSheet else { return }
        pendingSelectionAfterChildSheet = nil

        guard !isMutatingCourse else
        {
            ChooseCourseDebug.warning("子班 Sheet 关闭后未提交：已有写操作进行中")
            return
        }
        ChooseCourseDebug.info("子教学班 Sheet 已关闭，开始一次性选课提交")
        Task { await submitSelection(pending) }
    }

    /// 主教学班 Sheet 只负责让用户选教学班；浮层完全关闭后再继续读取子教学班或提交。
    @MainActor
    private func submitPendingSelectionAfterParentSheet()
    {
        guard let pending = pendingSelectionAfterParentSheet else { return }
        pendingSelectionAfterParentSheet = nil
        guard !isMutatingCourse else
        {
            ChooseCourseDebug.warning("主教学班 Sheet 关闭后未继续：已有写操作进行中")
            return
        }
        ChooseCourseDebug.info("主教学班 Sheet 已关闭，继续判断课程层级")
        startSelectionPreparation(
            for: pending.course,
            cookie: pending.cookie,
            semester: pending.semester
        )
    }

    private func alertContent(_ alert: CourseActionAlert) -> Alert
    {
        switch alert
        {
        case let .confirmation(item):
            switch item.action
            {
            case let .drop(course):
                return Alert(
                    title: Text("确认退选一次"),
                    message: Text("将向教务系统提交一次退选请求：\n\n\(course.courseName)\n\(course.displayTeachingClassName ?? "")\n\n退选会立即影响课表，且不会自动重复提交。"),
                    primaryButton: .cancel(Text("取消")),
                    secondaryButton: .destructive(Text("确认退选"), action: {
                        ChooseCourseDebug.info("用户在确认框确认退选")
                        Task { await submitDrop(course) }
                    })
                )
            }
        case let .feedback(item):
            return Alert(
                title: Text(item.title),
                message: Text(item.message),
                dismissButton: .default(Text("知道了"))
            )
        }
    }

    @MainActor
    private func loadSelectedCourses(cookie: String? = nil) async
    {
        guard !userinfo.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else
        {
            ChooseCourseDebug.warning("读取已选课程被拦截：当前没有登录教务账号")
            selectedCoursesError = "请先登录教务账号后再查询已选课程。"
            return
        }
        guard !isLoadingSelectedCourses else
        {
            ChooseCourseDebug.warning("忽略重复的已选课程读取请求")
            return
        }

        isLoadingSelectedCourses = true
        selectedCoursesError = nil
        semester = SelectedCourseSemester.current()
        let requestedSemester = semester
        ChooseCourseDebug.info("开始读取已选课程：\(requestedSemester.displayName)")
        do
        {
            let currentCookie: String
            if let cookie
            {
                currentCookie = cookie
            }
            else
            {
                currentCookie = try await loginForCourseSelection()
            }
            // 已选页顶部的学年/轮次/学分规则来自同一份选课页面。即使该展示请求失败，
            // 已选课程本身仍照常显示，并退回主页面已加载到的元数据。
            var overview = catalogOverview
            do
            {
                let pageContext = try await CourseSelectionPageLoader.load(
                    cookie: currentCookie,
                    semester: requestedSemester
                )
                overview = pageContext.overview
            }
            catch
            {
                ChooseCourseDebug.warning("已选页展示元数据读取失败，将使用已有元数据：\(error.localizedDescription)")
            }
            let courses = try await SelectedCourseQuery.shared.fetchSelectedCourses(
                cookie: currentCookie,
                semester: requestedSemester
            )
            selectedCourses = courses
            selectedCourseOverview = overview.replacingSelectedCredit(with: selectedCreditTotal(in: courses))
            isLoadingSelectedCourses = false
            ChooseCourseDebug.info("已选课程读取成功：\(courses.count) 门")
        }
        catch
        {
            ChooseCourseDebug.error("已选课程读取失败：\(error.localizedDescription)")
            selectedCoursesError = userFacingMessage(for: error)
            isLoadingSelectedCourses = false
        }
    }

    /// 清空当前目录并生成新的请求代号。旧请求即使晚返回，也不会覆盖新类别的结果。
    @MainActor
    private func invalidateCatalog() -> UUID
    {
        let requestID = UUID()
        catalogRequestID = requestID
        catalogCourses = []
        catalogError = nil
        catalogLoadMoreError = nil
        catalogHasMore = false
        catalogNextRangeStart = 1
        expandedCourseKey = nil
        expandedTeachingClasses = [:]
        expandingCourseKey = nil
        expandedCourseError = nil
        isLoadingCatalog = true
        isLoadingMoreCatalog = false
        semester = SelectedCourseSemester.current()
        return requestID
    }

    /// 首次进入、切换类别或下拉刷新时都从 1–10 重新读取。
    @MainActor
    private func reloadCatalog(using reusableCookie: String? = nil) async
    {
        let requestID = invalidateCatalog()
        await fetchCatalogPage(
            rangeStart: 1,
            rangeEnd: 10,
            reusableCookie: reusableCookie ?? catalogCookie,
            reset: true,
            requestID: requestID
        )
    }

    @MainActor
    private func categoryDidChange()
    {
        let requestID = invalidateCatalog()
        // onChange 不能直接等待异步函数；请求仍在同一 MainActor 状态链路中执行。
        let reusableCookie = catalogCookie
        Task
        {
            await fetchCatalogPage(
                rangeStart: 1,
                rangeEnd: 10,
                reusableCookie: reusableCookie,
                reset: true,
                requestID: requestID
            )
        }
    }

    @MainActor
    private func loadMoreCatalog()
    {
        guard catalogHasMore, !isLoadingCatalog, !isLoadingMoreCatalog, !isMutatingCourse else
        {
            return
        }
        let requestID = catalogRequestID
        let rangeStart = catalogNextRangeStart
        let rangeEnd = rangeStart + 9
        let reusableCookie = catalogCookie
        isLoadingMoreCatalog = true
        catalogLoadMoreError = nil
        Task
        {
            await fetchCatalogPage(
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
                reusableCookie: reusableCookie,
                reset: false,
                requestID: requestID
            )
        }
    }

    @MainActor
    private func fetchCatalogPage(
        rangeStart: Int,
        rangeEnd: Int,
        reusableCookie: String?,
        reset: Bool,
        requestID: UUID
    ) async
    {
        let requestedCategory = catalogCategory
        let requestedSemester = semester
        do
        {
            let cookie: String
            if let reusableCookie, !reusableCookie.isEmpty
            {
                cookie = reusableCookie
            }
            else
            {
                cookie = try await loginForCourseSelection()
            }
            let page = try await SearchCourse.shared.loadCatalog(
                category: requestedCategory,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
                cookie: cookie,
                semester: requestedSemester,
                keyword: appliedCatalogSearch
            )

            // 类别切换后，前一个网络请求的结果只能被丢弃，不能混入新列表。
            guard requestID == catalogRequestID, requestedCategory == catalogCategory else { return }
            var shouldContinue = page.hasMore
            if reset
            {
                catalogCourses = page.courses
                catalogOverview = page.overview
                isLoadingCatalog = false
            }
            else
            {
                let appendedCount = appendCatalogCourses(page.courses)
                isLoadingMoreCatalog = false
                if appendedCount == 0
                {
                    // 服务端偶尔忽略区间参数并重复返回上一段；继续触底只会形成请求
                    // 风暴，因此把它视为当前目录末尾并给出可见的“已加载全部”状态。
                    shouldContinue = false
                    ChooseCourseDebug.warning("课程目录追加结果全部重复，停止继续分页")
                }
            }
            catalogCookie = cookie
            catalogHasMore = shouldContinue
            catalogNextRangeStart = page.nextRangeStart
            catalogError = nil
            catalogLoadMoreError = nil
            ChooseCourseDebug.info(
                "UI 收到课程目录：类别=\(requestedCategory.title)，本次=\(page.courses.count)，累计=\(catalogCourses.count)"
            )

            if reset
            {
                // 目录和已选列表复用同一会话；回查后，已选课程会直接显示“退选”。
                Task
                {
                    await refreshCatalogSelectionState(
                        cookie: cookie,
                        semester: requestedSemester,
                        requestID: requestID
                    )
                }
            }
        }
        catch
        {
            guard requestID == catalogRequestID, requestedCategory == catalogCategory else { return }
            if reset
            {
                isLoadingCatalog = false
                catalogError = userFacingMessage(for: error)
                catalogCookie = nil
                ChooseCourseDebug.error("课程目录加载失败：\(error.localizedDescription)")
            }
            else
            {
                isLoadingMoreCatalog = false
                catalogLoadMoreError = "加载更多失败：\(userFacingMessage(for: error))"
                ChooseCourseDebug.error("课程目录追加加载失败：\(error.localizedDescription)")
            }
        }
    }

    @MainActor
    private func appendCatalogCourses(_ newCourses: [CourseSearchResult]) -> Int
    {
        var known = Set(catalogCourses.map(catalogIdentity))
        var appendedCount = 0
        for course in newCourses where known.insert(catalogIdentity(course)).inserted
        {
            catalogCourses.append(course)
            appendedCount += 1
        }
        return appendedCount
    }

    private func catalogIdentity(_ course: CourseSearchResult) -> String
    {
        // 目录已在 SearchCourse 按课程合并；分页追加时按课程卡片去重即可。
        course.catalogKey
    }

    /// 已选状态必须精确到教学班。课程号相同并不代表教学班相同，否则选中一个班后
    /// 同一门课的其它班也会错误显示为“退选”。优先比较教学班 ID，再比较会话 token。
    private func selectedCourse(for teachingClass: CourseSearchResult) -> SelectedCourse?
    {
        let classID = normalizedSelectionIdentifier(teachingClass.teachingClassID)
        let selectionToken = normalizedSelectionIdentifier(teachingClass.selectionToken)
        guard !classID.isEmpty || !selectionToken.isEmpty else { return nil }

        return selectedCourses.first
        { selected in
            if !classID.isEmpty,
               normalizedSelectionIdentifier(selected.teachingClassID) == classID
            {
                return true
            }
            guard !selectionToken.isEmpty else { return false }
            return selected.selectionTokens.contains
            { normalizedSelectionIdentifier($0) == selectionToken }
        }
    }

    private func normalizedSelectionIdentifier(_ value: String) -> String
    {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// 这个回查只更新目录的显示状态；真正退选时 CourseEdit 仍会重新登录、刷新并校验。
    @MainActor
    private func refreshCatalogSelectionState(
        cookie: String,
        semester: SelectedCourseSemester,
        requestID: UUID
    ) async
    {
        do
        {
            let current = try await SelectedCourseQuery.shared.fetchSelectedCourses(
                cookie: cookie,
                semester: semester
            )
            guard requestID == catalogRequestID else { return }
            selectedCourses = current
            selectedCourseOverview = catalogOverview.replacingSelectedCredit(with: selectedCreditTotal(in: current))
            ChooseCourseDebug.info("目录已选状态回查成功：\(current.count) 门")
        }
        catch
        {
            // 目录查询成功时，不让这项辅助读取把整页变成失败状态；点击选课前仍会强校验。
            ChooseCourseDebug.warning("目录已选状态回查失败：\(error.localizedDescription)")
        }
    }

    @MainActor
    private func submitCatalogSearch()
    {
        let normalized = catalogSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized != appliedCatalogSearch else { return }
        appliedCatalogSearch = normalized
        ChooseCourseDebug.info("用户提交课程搜索：关键词长度=\(normalized.count)")
        Task { await reloadCatalog() }
    }

    @MainActor
    private func clearCatalogSearch()
    {
        catalogSearchText = ""
        guard !appliedCatalogSearch.isEmpty else { return }
        appliedCatalogSearch = ""
        ChooseCourseDebug.info("用户清除课程搜索，恢复当前类别目录")
        Task { await reloadCatalog() }
    }

    /// 首层卡片只负责展开；详情读取完成后，用户再点击某个具体教学班的“选课”。
    /// 这样不会在用户还没看清教师/时间/容量时误触写请求。
    @MainActor
    private func toggleCourseExpansion(_ course: CourseSearchResult)
    {
        let key = course.catalogKey
        if expandedCourseKey == key
        {
            expandedCourseKey = nil
            expandingCourseKey = nil
            expandedCourseError = nil
            return
        }

        expandedCourseKey = key
        expandedCourseError = nil
        guard !isMutatingCourse else { return }
        guard let catalogCookie, !catalogCookie.isEmpty else
        {
            activeAlert = .feedback(CourseActionFeedback(
                title: "课程目录会话已失效",
                message: "请下拉刷新课程目录后再展开教学班，本次没有提交选课请求。",
                kind: .warning
            ))
            return
        }

        if expandedTeachingClasses[key] != nil
        {
            return
        }

        let requestID = catalogRequestID
        expandingCourseKey = key
        ChooseCourseDebug.info("用户展开课程，读取教学班详情：课程号=\(course.courseCode)")
        Task
        {
            do
            {
                let classes = try await SearchCourse.shared.loadCurrentTeachingClasses(
                    for: course,
                    cookie: catalogCookie
                )
                await MainActor.run
                {
                    guard requestID == catalogRequestID, expandedCourseKey == key else { return }
                    expandedTeachingClasses[key] = classes
                    expandingCourseKey = nil
                    ChooseCourseDebug.info("教学班详情读取成功：课程号=\(course.courseCode)，教学班=\(classes.count)")
                }
            }
            catch
            {
                await MainActor.run
                {
                    guard requestID == catalogRequestID, expandedCourseKey == key else { return }
                    expandingCourseKey = nil
                    expandedCourseError = userFacingMessage(for: error)
                    ChooseCourseDebug.error("教学班详情读取失败：\(error.localizedDescription)")
                }
            }
        }
    }

    @MainActor
    private func retryCourseExpansion(_ course: CourseSearchResult)
    {
        let key = course.catalogKey
        guard expandedCourseKey == key else
        {
            toggleCourseExpansion(course)
            return
        }
        // 让同一张卡片从“未展开”重新走一次只读详情请求，而不是把错误状态当作折叠。
        expandedTeachingClasses[key] = nil
        expandedCourseError = nil
        expandedCourseKey = nil
        toggleCourseExpansion(course)
    }

    private func selectedCreditTotal(in courses: [SelectedCourse]) -> Double
    {
        courses.reduce(0)
        { total, course in
            let normalized = (course.displayCredit ?? "")
                .replacingOccurrences(of: "，", with: ".")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return total + (Double(normalized) ?? 0)
        }
    }

    @MainActor
    private func beginSelection(_ course: CourseSearchResult)
    {
        ChooseCourseDebug.info("UI 点击选课：课程号=\(course.courseCode)，层级=\(course.classLevels)")
        guard let catalogCookie, !catalogCookie.isEmpty else
        {
            ChooseCourseDebug.warning("选课被拦截：课程目录会话 Cookie 不存在")
            activeAlert = .feedback(CourseActionFeedback(
                title: "课程目录会话已失效",
                message: "请下拉刷新课程目录后再选课，本次没有提交请求。",
                kind: .warning
            ))
            return
        }
        guard !isPreparingSelection, !isMutatingCourse else
        {
            ChooseCourseDebug.warning("选课点击被忽略：当前仍在读取子班或提交上一项操作")
            return
        }

        let currentSemester = semester
        if course.hasCurrentSelectionParameters
        {
            startSelectionPreparation(
                for: course,
                cookie: catalogCookie,
                semester: currentSemester
            )
            return
        }

        // 目录响应通常只有课程摘要；先按用户点击的这一门课补全主教学班，避免首屏
        // 为所有课程逐一请求详情。
        isPreparingSelection = true
        ChooseCourseDebug.info("课程尚未带主教学班参数，开始按需补全")
        Task
        {
            do
            {
                let parentClasses = try await SearchCourse.shared.resolveCurrentParentClasses(
                    for: course,
                    cookie: catalogCookie
                )
                await MainActor.run
                {
                    isPreparingSelection = false
                    if parentClasses.count == 1, let parentClass = parentClasses.first
                    {
                        startSelectionPreparation(
                            for: parentClass,
                            cookie: catalogCookie,
                            semester: currentSemester
                        )
                    }
                    else
                    {
                        ChooseCourseDebug.info("主教学班补全返回多个选项，展示主教学班 Sheet（\(parentClasses.count)项）")
                        parentSelectionState = ParentSelectionState(
                            course: course,
                            parentClasses: parentClasses,
                            cookie: catalogCookie,
                            semester: currentSemester
                        )
                    }
                }
            }
            catch
            {
                await MainActor.run
                {
                    isPreparingSelection = false
                    ChooseCourseDebug.error("准备选课失败：\(error.localizedDescription)")
                    showErrorFeedback(error)
                }
            }
        }
    }

    /// 主教学班参数准备好后，统一进入“单层直接提交 / 多层子班 Sheet”判断。
    @MainActor
    private func startSelectionPreparation(
        for course: CourseSearchResult,
        cookie: String,
        semester: SelectedCourseSemester
    )
    {
        guard !isPreparingSelection, !isMutatingCourse else
        {
            ChooseCourseDebug.warning("选课准备被忽略：当前仍有另一个准备或提交流程")
            return
        }
        isPreparingSelection = true
        ChooseCourseDebug.info("开始判断课程是否需要子教学班")
        Task
        {
            do
            {
                let preparation = try await CourseEdit.shared.prepareSelection(
                    for: course,
                    cookie: cookie,
                    semester: semester
                )
                await MainActor.run
                {
                    isPreparingSelection = false
                    switch preparation
                    {
                    case let .direct(teachingClass):
                        ChooseCourseDebug.info("UI 判断为单层课程，开始一次性选课提交")
                        let pending = PendingSelection(
                            course: course,
                            childClass: teachingClass,
                            cookie: cookie,
                            semester: semester
                        )
                        Task { await submitSelection(pending) }
                    case let .needsChildSelection(childClasses):
                        ChooseCourseDebug.info("UI 判断为多层课程，展示子教学班 Sheet（\(childClasses.count)项）")
                        childSelectionState = ChildSelectionState(
                            course: course,
                            childClasses: childClasses,
                            cookie: cookie,
                            semester: semester
                        )
                    }
                }
            }
            catch
            {
                await MainActor.run
                {
                    isPreparingSelection = false
                    ChooseCourseDebug.error("准备选课失败：\(error.localizedDescription)")
                    showErrorFeedback(error)
                }
            }
        }
    }

    @MainActor
    private func requestDropConfirmation(_ course: SelectedCourse)
    {
        guard !isMutatingCourse else
        {
            ChooseCourseDebug.warning("退选点击被忽略：当前已有写操作进行中")
            return
        }
        ChooseCourseDebug.info("UI 点击退选：课程号=\(course.courseCode ?? course.courseID)")
        activeAlert = .confirmation(.drop(course))
    }

    @MainActor
    private func submitSelection(_ pending: PendingSelection) async
    {
        guard !isMutatingCourse else
        {
            ChooseCourseDebug.warning("选课确认被忽略：已有写操作进行中")
            return
        }
        isMutatingCourse = true
        ChooseCourseDebug.info("UI 开始执行一次性选课提交")
        do
        {
            let result = try await CourseEdit.shared.select(
                course: pending.course,
                teachingClass: pending.childClass,
                cookie: pending.cookie,
                semester: pending.semester
            )
            isMutatingCourse = false
            showFeedback(for: result, successTitle: "选课结果")
            if result.succeeded
            {
                // 选课成功后让目录从当前会话重新开始，避免继续显示刚刚已选上的课程。
                await reloadCatalog(using: pending.cookie)
            }
            else if result.verified == true
            {
                // 重复选课提示代表教务已确认该课程存在于已选列表，直接把入口更新为退选。
                await refreshCatalogSelectionState(
                    cookie: pending.cookie,
                    semester: pending.semester,
                    requestID: catalogRequestID
                )
            }
        }
        catch
        {
            isMutatingCourse = false
            ChooseCourseDebug.error("选课提交流程异常：\(error.localizedDescription)")
            showErrorFeedback(error)
        }
    }

    @MainActor
    private func submitDrop(_ course: SelectedCourse) async
    {
        guard !isMutatingCourse else
        {
            ChooseCourseDebug.warning("退选确认被忽略：已有写操作进行中")
            return
        }
        isMutatingCourse = true
        ChooseCourseDebug.info("UI 开始执行一次性退选提交")
        do
        {
            let cookie = try await loginForCourseSelection()
            let result = try await CourseEdit.shared.drop(
                course: course,
                cookie: cookie,
                semester: semester
            )
            isMutatingCourse = false
            showFeedback(for: result, successTitle: "退选结果")
            if result.succeeded
            {
                await loadSelectedCourses(cookie: cookie)
                await reloadCatalog(using: cookie)
            }
        }
        catch
        {
            isMutatingCourse = false
            ChooseCourseDebug.error("退选提交流程异常：\(error.localizedDescription)")
            showErrorFeedback(error)
        }
    }

    @MainActor
    private func loginForCourseSelection() async throws -> String
    {
        ChooseCourseDebug.info("开始获取本次选课会话 Cookie")
        let cookie = try await scheduleQuery.loginAndGetCookie(
            username: userinfo.username,
            rsaPassword: userinfo.encryptedPasswordSchool,
            mfaCodeProvider: { phone in
                await requestMFACode(maskedPhone: phone)
            }
        )
        ChooseCourseDebug.info("选课会话 Cookie 获取成功（内容已隐藏）")
        return cookie
    }

    @MainActor
    private func showFeedback(for result: CourseMutationResult, successTitle: String)
    {
        let kind: CourseActionFeedback.Kind
        switch result.status
        {
        case .success:
            kind = .success
        case .rejected:
            kind = .error
        case .unknown:
            kind = .warning
        }
        activeAlert = .feedback(CourseActionFeedback(title: successTitle, message: result.message, kind: kind))
        ChooseCourseDebug.info("UI 展示\(successTitle)：状态=\(feedbackStatusName(kind))")
        notify(kind)
    }

    @MainActor
    private func showErrorFeedback(_ error: Error)
    {
        ChooseCourseDebug.error("UI 展示错误反馈：\(error.localizedDescription)")
        activeAlert = .feedback(CourseActionFeedback(title: "操作未完成", message: userFacingMessage(for: error), kind: .error))
        notify(.error)
    }

    @MainActor
    private func notify(_ kind: CourseActionFeedback.Kind)
    {
        let feedbackGenerator = UINotificationFeedbackGenerator()
        switch kind
        {
        case .success:
            feedbackGenerator.notificationOccurred(.success)
        case .warning:
            feedbackGenerator.notificationOccurred(.warning)
        case .error:
            feedbackGenerator.notificationOccurred(.error)
        }
    }

    private func userFacingMessage(for error: Error) -> String
    {
        if let queryError = error as? SelectedCourseQueryError
        {
            return queryError.localizedDescription
        }
        if let selectionError = error as? CourseSelectionServiceError
        {
            return selectionError.localizedDescription
        }

        let errorInfo = error as NSError
        if errorInfo.domain == "LoginFailed" || errorInfo.domain == "NoLocationStep2"
        {
            return "教务登录失败，请检查账号信息后重试。"
        }
        return error.localizedDescription
    }

    @MainActor
    private func requestMFACode(maskedPhone: String?) async -> String?
    {
        ChooseCourseDebug.info("选课登录需要二次验证，展示验证码输入 Sheet")
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
    private func resolveMFACode(_ code: String?)
    {
        ChooseCourseDebug.info("二次验证输入结束：\(code?.isEmpty == false ? "已输入" : "已取消或为空")")
        showMFASheet = false
        mfaContinuation?.resume(returning: code)
        mfaContinuation = nil
        mfaSendCodeAction = nil
    }

    private func feedbackStatusName(_ kind: CourseActionFeedback.Kind) -> String
    {
        switch kind
        {
        case .success: return "成功"
        case .warning: return "提示"
        case .error: return "错误"
        }
    }
}

/// 选课相关网络流程的统一居中提示。透明命中层会在请求期间挡住重复点击，
/// 但不额外加深整页颜色，仍保持系统分组背景的层次。
struct CourseCenteredLoadingOverlay: View
{
    let message: String

    var body: some View
    {
        ZStack
        {
            Color.black.opacity(0.001)
                .ignoresSafeArea()

            VStack(spacing: 13)
            {
                ProgressView()
                    .controlSize(.large)
                Text(message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 280)
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay
            {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.10), radius: 12, y: 5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

private struct PendingSelection
{
    let course: CourseSearchResult
    let childClass: CourseChildClass
    let cookie: String
    let semester: SelectedCourseSemester
}

private struct PendingParentSelection
{
    let course: CourseSearchResult
    let cookie: String
    let semester: SelectedCourseSemester
}

private struct ParentSelectionState: Identifiable
{
    let id = UUID()
    let course: CourseSearchResult
    let parentClasses: [CourseSearchResult]
    let cookie: String
    let semester: SelectedCourseSemester
}

private struct ChildSelectionState: Identifiable
{
    let id = UUID()
    let course: CourseSearchResult
    let childClasses: [CourseChildClass]
    let cookie: String
    let semester: SelectedCourseSemester
}

private struct CourseActionConfirmation: Identifiable
{
    enum Action
    {
        case drop(SelectedCourse)
    }

    let id = UUID()
    let action: Action

    static func drop(_ course: SelectedCourse) -> CourseActionConfirmation
    {
        CourseActionConfirmation(action: .drop(course))
    }
}

private struct CourseActionFeedback: Identifiable
{
    enum Kind
    {
        case success
        case warning
        case error
    }

    let id = UUID()
    let title: String
    let message: String
    let kind: Kind
}

/// 选课页只挂载一个 Alert；这样确认框和结果提示不会互相覆盖。
private enum CourseActionAlert: Identifiable
{
    case confirmation(CourseActionConfirmation)
    case feedback(CourseActionFeedback)

    var id: UUID
    {
        switch self
        {
        case let .confirmation(value): return value.id
        case let .feedback(value): return value.id
        }
    }
}

/// 当一门课程返回多个主教学班时，先让用户选定主班，再继续原有子班流程。
private struct ParentCoursePickerSheet: View
{
    let course: CourseSearchResult
    let parentClasses: [CourseSearchResult]
    let onSelect: (CourseSearchResult) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View
    {
        NavigationStack
        {
            List(parentClasses)
            { parentClass in
                Button
                {
                    onSelect(parentClass)
                } label: {
                    HStack(spacing: 12)
                    {
                        VStack(alignment: .leading, spacing: 5)
                        {
                            Text(parentClass.teachingClassName.ifEmpty("教学班"))
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(parentClass.requiresChildClass ? "选择后还需选择子教学班" : "可直接选课")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 5)
                }
            }
            .navigationTitle("选择教学班")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar
            {
                ToolbarItem(placement: .topBarLeading)
                {
                    Button("取消", action: dismiss.callAsFunction)
                }
            }
            .safeAreaInset(edge: .top)
            {
                Text(course.displayTitle)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.bar)
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct ChildCoursePickerSheet: View
{
    let course: CourseSearchResult
    let childClasses: [CourseChildClass]
    let onSelect: (CourseChildClass) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View
    {
        NavigationStack
        {
            ScrollView
            {
                LazyVStack(alignment: .leading, spacing: 14)
                {
                    VStack(alignment: .leading, spacing: 5)
                    {
                        Text("主课程")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(course.courseName)
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.bottom, 4)

                    ForEach(childClasses)
                    { childClass in
                        ChildClassSelectionCard(
                            childClass: childClass,
                            onSelect: { onSelect(childClass) }
                        )
                    }
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("选择子教学班")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar
            {
                ToolbarItem(placement: .topBarLeading)
                {
                    Button("取消", action: dismiss.callAsFunction)
                }
            }
        }
        // 不使用 clear / material 背景：这是标准不透明 Sheet，避免后面的目录颜色透进来。
        .presentationDetents([.large])
    }
}

/// 子教学班使用深灰色的实体卡片与白字，和父页面的中性灰层级区分开；
/// 容量固定紧跟教学班标题，底部按钮只保留“选课”这个动作词。
private struct ChildClassSelectionCard: View
{
    let childClass: CourseChildClass
    let onSelect: () -> Void

    private var capacityStatus: CourseCapacityStatus { childClass.capacityStatus }
    /// 第一轮等阶段可能不限容量，甚至会出现已选人数大于容量的显示。
    /// 容量只负责提示；只要教务返回了有效 token，就允许把一次请求交给服务器裁决。
    private var canSelect: Bool { childClass.canSelect }

    var body: some View
    {
        VStack(alignment: .leading, spacing: 11)
        {
            Text(childClass.name)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            Text(capacityStatus.availabilityText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(capacityStatus.tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(capacityStatus.tint.opacity(0.20), in: Capsule())

            if childClass.teacher != "--"
            {
                Label(childClass.teacher, systemImage: "person.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.92))
            }
            if childClass.schedule != "--"
            {
                Label(childClass.schedule, systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if childClass.location != "--"
            {
                Label(childClass.location, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onSelect)
            {
                Text("选课")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(capacityStatus.buttonForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(capacityStatus.tint.opacity(canSelect ? 0.92 : 0.32), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canSelect)
            .accessibilityLabel("选课")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(uiColor: .darkGray), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
