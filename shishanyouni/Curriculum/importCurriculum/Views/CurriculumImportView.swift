import SwiftUI

/// 两种来源各自完成认证和取数；只有选中的来源会写入本地课表。
struct CurriculumImportView: View
{
    @StateObject private var backendMFA = ShishanyouniMFAPresenter()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userinfo: userInfo
    @Binding var courses: [Course]
    let onImported: (Date?) -> Void

    @State private var source: CurriculumImportSource = .shishanyouni
    @State private var year = AcademicQuerySemester.forDate(Date()).year
    @State private var term = AcademicQuerySemester.forDate(Date()).term
    @State private var isImporting = false
    @State private var resultMessage = ""
    @State private var importedCourses: [Course] = []
    @State private var importTask: Task<Void, Never>?
    @State private var showManualChoice = false
    @State private var showAssessmentOffer = false
    @State private var showImportNotice = false

    @State private var showMFASheet = false
    @State private var mfaFromBackend = false
    @State private var mfaPhone = ""
    @State private var mfaCode = ""
    @State private var sendCodeAction: (() async -> String?)?
    @State private var codeContinuation: CheckedContinuation<String?, Never>?
    @State private var pendingMFACode: String?

    private var availableYears: [String]
    {
        let current = Int(AcademicQuerySemester.forDate(Date()).year) ?? Calendar.current.component(.year, from: Date())
        return ((current - 3) ... (current + 2)).map(String.init)
    }

    var body: some View
    {
        NavigationStack
        {
            Form
            {
                Section("导入来源")
                {
                    DataSourceTabs(selection: $source)
                    Text(source == .shishanyouni
                         ? "通过狮山有你获取课表。完成后可选择登录\(SchoolServiceName.academicPlatform)补充考核方式。"
                         : "使用\(SchoolServiceName.unifiedIdentity)账号直接登录\(SchoolServiceName.academicPlatform)。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .disabled(isImporting)

                Section("导入学期")
                {
                    Picker("学年", selection: $year)
                    {
                        ForEach(availableYears, id: \.self)
                        { value in
                            Text(verbatim: "\(value)-\((Int(value) ?? 0) + 1)").tag(value)
                        }
                    }
                    Picker("学期", selection: $term)
                    {
                        Text("第一学期").tag("1")
                        Text("第二学期").tag("2")
                    }
                }
                .disabled(isImporting)

                Section
                {
                    AcceptButton(isImporting ? "处理中…" : "导入课表")
                    {
                        if courses.contains(where: \.isManual) { showManualChoice = true }
                        else { beginImport(keepManual: false) }
                    }
                    .disabled(isImporting)
                    .confirmationDialog("是否保留手动添加的课程？", isPresented: $showManualChoice, titleVisibility: .visible)
                    {
                        Button("保留手动课程") { beginImport(keepManual: true) }
                        Button("清除手动课程", role: .destructive) { beginImport(keepManual: false) }
                        Button("取消", role: .cancel) {}
                    }
                    message:
                    {
                        Text("本次导入会替换原有的导入课程，不会叠加两种来源的重复课表。")
                    }
                    .listRowBackground(Color.clear)
                }
                footer:
                {
                    Text("导入会替换已有的导入课程，不会将两种来源叠加；手动课程可选择保留。")
                }

                if isImporting
                {
                    VStack(spacing: 10)
                    {
                        ProgressView()
                        Text("正在处理，请稍候")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                    .accessibilityElement(children: .combine)
                }
                if !resultMessage.isEmpty
                {
                    Section("导入结果")
                    {
                        Text(resultMessage)
                            .font(.subheadline)
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("导入课表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar
            {
                ToolbarItem(placement: .cancellationAction)
                {
                    Button("完成") { dismiss() }
                        .disabled(isImporting)
                }
            }
            .alert("是否使用\(SchoolServiceName.unifiedIdentity)账号登录\(SchoolServiceName.academicPlatform)？", isPresented: $showAssessmentOffer)
            {
                Button("继续补充考核方式")
                {
                    importTask = Task { await supplementAssessmentMethods() }
                }
                Button("暂不补充", role: .cancel) {}
            }
            message:
            {
                Text("狮山有你课表已导入。可继续从\(SchoolServiceName.academicPlatform)补充“考试／考查”，可能需要短信验证；跳过不影响已导入的课表。")
            }
            .alert("课表导入结果", isPresented: $showImportNotice)
            {
                Button("确定", role: .cancel) {}
            }
            message: { Text(resultMessage) }
            .sheet(isPresented: $showMFASheet, onDismiss: finishCodeRequest)
            {
                MFACodeInputSheet(
                    maskedPhone: mfaPhone, code: $mfaCode, fromShishanyouni: mfaFromBackend,
                    onSendCode: $sendCodeAction,
                    onCancel: { dismissMFASheet(with: nil) },
                    onConfirm: { dismissMFASheet(with: mfaCode.trimmingCharacters(in: .whitespacesAndNewlines)) }
                )
            }
        }
        .shishanyouniMFA(backendMFA)
        .interactiveDismissDisabled(isImporting)
        .onDisappear
        {
            importTask?.cancel()
            pendingMFACode = nil
            showMFASheet = false
            finishCodeRequest()
        }
    }

    @MainActor
    private func beginImport(keepManual: Bool)
    {
        guard !isImporting else { return }
        isImporting = true
        resultMessage = ""
        importTask = Task
        {
            defer { isImporting = false }
            let username = userinfo.username
            let selectedSource = source
            do
            {
                guard !username.isEmpty else { throw CurriculumError.apiError("请先登录账号。") }
                let result: (courses: [Course], startDate: Date?)
                switch selectedSource
                {
                case .shishanyouni:
                    result = try await fetchFromShishanyouni()
                case .academic:
                    // 教务导入只使用 CAS 凭据和学校接口，不依赖狮山有你的绑定或 Token。
                    let cookie = try await academicCookie()
                    result = try await AcademicCurriculumImporter.fetchCourses(cookie: cookie, year: year, term: term)
                }
                try Task.checkCancellation()
                guard username == userinfo.username else { throw CurriculumError.apiError("账号已更换，未覆盖原课表，请重新导入。") }
                guard !result.courses.isEmpty else
                {
                    resultMessage = "所选学期未查到课程，现有课表未更改。"
                    showImportNotice = true
                    return
                }

                importedCourses = result.courses
                let manual = keepManual ? courses.filter(\.isManual) : []
                courses = manual + result.courses
                CurriculumStore.shared.saveCourses(courses, semesterStart: nil)
                onImported(result.startDate)

                let regularCount = result.courses.filter { $0.courseType == .regular }.count
                let others = result.courses.filter { $0.courseType == .other }
                resultMessage = "已通过\(selectedSource.title)导入 \(regularCount) 条普通排课、\(others.count) 门其他课程。"
                if !others.isEmpty
                {
                    resultMessage += "\n\n其他课程：\(others.map(\.name).joined(separator: "、"))。\n实践课程及其他课程已放入“所有课程”，可查看、编辑周次；没有固定时段的课程不占用课表格子。"
                }
                resultMessage += result.startDate == nil
                    ? "\n\n请在课表设置中确认开学日期并保存。"
                    : "\n\n开学日期已填写，请返回课表设置确认并保存。"
                if selectedSource == .shishanyouni { showAssessmentOffer = true }
                else { showImportNotice = true }
            }
            catch is CancellationError {}
            catch
            {
                resultMessage = "导入失败：\(error.localizedDescription)"
                showImportNotice = true
            }
        }
    }

    @MainActor
    private func fetchFromShishanyouni() async throws -> (courses: [Course], startDate: Date?)
    {
        let username = userinfo.username
        let result = try await ShishanyouniCurriculumImporter.fetchCourses(
            username: username, encryptedPassword: userinfo.encryptedPasswordShishanyouni,
            year: year, term: term, mfa: backendMFA.provider
        )
        guard username == userinfo.username else { throw CancellationError() }
        return result
    }

    @MainActor
    private func academicCookie() async throws -> String
    {
        guard !userinfo.encryptedPasswordSchool.isEmpty else { throw CurriculumError.apiError("缺少\(SchoolServiceName.unifiedIdentity)登录信息，请先绑定账号。") }
        return try await SchoolAcademicAPI().loginAndGetCookie(
            username: userinfo.username, rsaPassword: userinfo.encryptedPasswordSchool,
            mfaCodeProvider: { phone in
                await requestCode(phone: phone ?? "", fromBackend: false, send: MFACodeContext.activeSendCodeAction)
            }
        )
    }

    @MainActor
    private func supplementAssessmentMethods() async
    {
        isImporting = true
        defer { isImporting = false }
        let username = userinfo.username
        do
        {
            let cookie = try await academicCookie()
            let methods = try await CurriculumAssessmentService.fetchAssessmentMethods(cookie: cookie, year: year, appTerm: term)
            try Task.checkCancellation()
            guard username == userinfo.username else { throw CurriculumError.apiError("账号已更换，未补充考核方式。") }
            let importedIDs = Set(importedCourses.map(\.id))
            courses = courses.map
            { course in
                guard importedIDs.contains(course.id), let method = methods[course.name] else { return course }
                var updated = course
                updated.assessmentMethod = method
                return updated
            }
            CurriculumStore.shared.saveCourses(courses, semesterStart: nil)
            let count = courses.filter { importedIDs.contains($0.id) && methods[$0.name] != nil }.count
            resultMessage += count > 0
                ? "\n\n已从\(SchoolServiceName.academicPlatform)为 \(count) 条排课补充考核方式。"
                : "\n\n\(SchoolServiceName.academicPlatform)没有返回可匹配的考试／考查信息，已导入的课表保留。"
        }
        catch is CancellationError {}
        catch { resultMessage += "\n\n未补充考核方式：\(error.localizedDescription)\n已导入的课表保留。" }
    }

    @MainActor
    private func requestCode(phone: String, fromBackend: Bool, send: (() async -> String?)?) async -> String?
    {
        guard !Task.isCancelled else { return nil }
        mfaPhone = phone
        mfaCode = ""
        mfaFromBackend = fromBackend
        sendCodeAction = send
        pendingMFACode = nil
        return await withCheckedContinuation
        { continuation in
            codeContinuation = continuation
            showMFASheet = true
        }
    }

    @MainActor
    private func dismissMFASheet(with code: String?)
    {
        pendingMFACode = code
        showMFASheet = false
    }

    /// 等验证 Sheet 的收起转场结束再继续请求，避免结果提示被尚未收起的 Sheet 挡住。
    @MainActor
    private func finishCodeRequest()
    {
        codeContinuation?.resume(returning: pendingMFACode)
        codeContinuation = nil
        pendingMFACode = nil
        sendCodeAction = nil
    }
}
