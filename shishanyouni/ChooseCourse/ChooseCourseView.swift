//
//  ChooseCourseView.swift
//  shishanyouni
//

import SwiftUI

/// 选课功能的入口页。当前仅展示已选课程，后续选课操作会单独接入。
struct ChooseCourseView: View
{
    @EnvironmentObject var userinfo: userInfo

    @State private var selectedCourses: [SelectedCourse] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var semester = SelectedCourseSemester.current()
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
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            content
        }
        .navigationTitle("选课")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar
        {
            ToolbarItem(placement: .topBarTrailing)
            {
                Button
                {
                    Task { await loadSelectedCourses() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
                .accessibilityLabel("刷新已选课程")
            }
        }
        .task
        {
            if selectedCourses.isEmpty { await loadSelectedCourses() }
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

    @ViewBuilder
    private var content: some View
    {
        if isLoading, selectedCourses.isEmpty
        {
            ProgressView("正在登录并读取已选课程...")
        }
        else if let errorMessage
        {
            ChooseCourseStateView(
                title: "暂时无法读取已选课程",
                icon: "exclamationmark.triangle.fill",
                description: errorMessage,
                actionTitle: "重试"
            )
            {
                Task { await loadSelectedCourses() }
            }
        }
        else if selectedCourses.isEmpty
        {
            ChooseCourseStateView(
                title: "暂无已选课程",
                icon: "checklist",
                description: "\(semester.displayName) 未查询到可展示的已选课程。"
            )
        }
        else
        {
            List
            {
                Section
                {
                    ForEach(selectedCourses)
                    { course in
                        SelectedCourseRow(course: course)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                } header: {
                    HStack
                    {
                        Text(semester.displayName)
                        Spacer()
                        Text("共 \(selectedCourses.count) 门")
                    }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .textCase(nil)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .refreshable { await loadSelectedCourses() }
            .overlay(alignment: .top)
            {
                if isLoading
                {
                    ProgressView()
                        .padding(10)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.top, 6)
                }
            }
        }
    }

    private func loadSelectedCourses() async
    {
        guard !userinfo.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else
        {
            errorMessage = "请先登录教务账号后再查询已选课程。"
            return
        }
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        semester = SelectedCourseSemester.current()

        do
        {
            let cookie = try await scheduleQuery.loginAndGetCookie(
                username: userinfo.username,
                rsaPassword: userinfo.encryptedPasswordSchool,
                mfaCodeProvider: { phone in
                    await requestMFACode(maskedPhone: phone)
                }
            )
            let courses = try await SelectedCourseQuery.shared.fetchSelectedCourses(
                cookie: cookie,
                semester: semester
            )

            await MainActor.run
            {
                selectedCourses = courses
                isLoading = false
            }
        }
        catch
        {
            await MainActor.run
            {
                errorMessage = userFacingMessage(for: error)
                isLoading = false
            }
        }
    }

    private func userFacingMessage(for error: Error) -> String
    {
        if let queryError = error as? SelectedCourseQueryError
        {
            return queryError.localizedDescription
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
        showMFASheet = false
        mfaContinuation?.resume(returning: code)
        mfaContinuation = nil
        mfaSendCodeAction = nil
    }
}

private struct SelectedCourseRow: View
{
    let course: SelectedCourse

    var body: some View
    {
        VStack(alignment: .leading, spacing: 12)
        {
            HStack(alignment: .top, spacing: 12)
            {
                VStack(alignment: .leading, spacing: 4)
                {
                    Text(course.courseName)
                        .font(.system(size: 18, weight: .bold))
                        .textSelection(.enabled)

                    if let teachingClassName = course.displayTeachingClassName
                    {
                        Text(teachingClassName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                Spacer(minLength: 8)

                if let courseCode = course.displayCourseCode
                {
                    Text(courseCode)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .textSelection(.enabled)
                }
            }

            HStack(spacing: 8)
            {
                if let type = course.displayCourseType
                {
                    CourseTag(title: type, color: .blue)
                }
                if let credit = course.displayCredit
                {
                    CourseTag(title: "\(credit) 学分", color: .orange)
                }
                if let enrollment = course.enrollmentText
                {
                    CourseTag(title: enrollment, color: .green)
                }
            }

            VStack(alignment: .leading, spacing: 7)
            {
                CourseMetaRow(icon: "person.fill", text: course.teacherName)

                if let time = course.displayClassTime
                {
                    CourseMetaRow(icon: "calendar", text: time)
                }
                if let location = course.displayLocation
                {
                    CourseMetaRow(icon: "mappin.and.ellipse", text: location)
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ChooseCourseStateView: View
{
    let title: String
    let icon: String
    let description: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View
    {
        VStack(spacing: 16)
        {
            Image(systemName: icon)
                .font(.system(size: 52))
                .foregroundStyle(.blue)

            VStack(spacing: 7)
            {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action
            {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
    }
}

private struct CourseTag: View
{
    let title: String
    let color: Color

    var body: some View
    {
        Text(title)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }
}

private struct CourseMetaRow: View
{
    let icon: String
    let text: String

    var body: some View
    {
        Label(text, systemImage: icon)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
    }
}
