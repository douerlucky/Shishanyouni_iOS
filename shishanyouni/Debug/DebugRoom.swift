//
//  DebugRoom.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/8.
//

import SwiftUI
import WebKit

struct DebugRoom: View
{
    @State private var webViewRef: WKWebView? = nil
    @State private var showWeb = false
    @State private var showMFASheet = false
    @State private var mfaMaskedPhone = ""
    @State private var mfaCode = ""
    @State private var mfaContinuation: CheckedContinuation<String?, Never>?
    @State private var randomFPVisitorEnabled = CASMFADebug.randomFPVisitorEnabled
    @State private var fpRefreshTick = 0

    @State var cookieInput: String = ""

    @EnvironmentObject var userinfo: userInfo

    private let loginURL = URL(string: "https://cas-paas.hzau.edu.cn/cas/login?service=https://portal-paas.hzau.edu.cn/")!

    var body: some View
    {
        ScrollView
        {
            VStack
            {
                Button("打开登录页（WKWebView）")
                {
                    showWeb = true
                }
                .buttonStyle(.borderedProminent)

                ScrollView
                {
                    Text(cookieInput)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                }
                .frame(maxHeight: 240)

                VStack(spacing: 16)
                {
                    Text("粘贴 Cookie（JSESSIONID=xxx）")
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextEditor(text: $cookieInput)
                        .frame(height: 80)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.gray.opacity(0.3)))
                }

                VStack(spacing: 12)
                {
                    TextField("学号", text: $userinfo.username)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Text("🔐 RSA 加密实验室")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("输入原始密码", text: $userinfo.plainPassword)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button("执行 RSA 加密")
                    {
                        userinfo.performSchoolEncryption()
                        print("✅ 加密成功!")
                        print(userinfo.encryptedPasswordSchool)
                    }
                    .buttonStyle(.bordered)

                    Button("设定该学号密码")
                    {
                        userinfo.performSchoolEncryption()
                        userinfo.debugprint()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(12)

                Button("当前学号密码")
                {
                    userinfo.debugprint()
                }

                VStack(alignment: .leading, spacing: 10)
                {
                    Toggle("MFA 使用随机 fpVisitorId（更容易触发 need=true）", isOn: $randomFPVisitorEnabled)
                        .onChange(of: randomFPVisitorEnabled) { newValue in
                            CASMFADebug.setRandomFPVisitorEnabled(newValue)
                        }

                    Text("当前 fpVisitorId: \(CASMFADebug.fpVisitorId)")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .id(fpRefreshTick)

                    Button("重新生成 fpVisitorId")
                    {
                        CASMFADebug.regenerateFPVisitorId()
                        fpRefreshTick += 1
                    }
                    .buttonStyle(.bordered)

                    Button("预览验证码弹窗页面")
                    {
                        mfaMaskedPhone = "133****0922"
                        mfaCode = ""
                        showMFASheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color.orange.opacity(0.08))
                .cornerRadius(12)

                // MARK: - 课表接口测试（lion API，无需 CAS）

                Button("测试查询课表接口")
                {
                    Task
                    {
                        do
                        {
                            print("🚀 开始测试课表接口...")
                            let (courses, startDate) = try await ScheduleService.fetchCourses(
                                username: userinfo.username,
                                password: userinfo.plainPassword,
                                year:     "2025",
                                term:     "2"
                            )
                            print("✅ 成功获取 \(courses.count) 门课程")
                            print("📅 开学日期: \(startDate.map { "\($0)" } ?? "未返回")")
                        }
                        catch
                        {
                            debugPrintError(error)
                        }
                    }
                }

                // MARK: - 考试接口测试（lion API，无需 CAS）

                Button("测试考试查询接口")
                {
//                    Task
//                    {
//                        do
//                        {
//                            print("🚀 开始测试考试接口...")
//                            let exams = try await ExamService.fetchExams(
//                                username: userinfo.username,
//                                password: userinfo.plainPassword,
//                                year:     "2025",
//                                term:     "2"
//                            )
//                            print("✅ 成功获取 \(exams.count) 条考试安排")
//                            for exam in exams
//                            {
//                                print("  • \(exam.kcmc)  \(exam.examDate) \(exam.examTime)  \(exam.cdmc ?? "无场地")")
//                            }
//                        }
//                        catch
//                        {
//                            debugPrintError(error)
//                        }
//                    }
                }

                // MARK: - 南湖跑接口测试（保持原有逻辑）

                Button("测试 CAS 登录接口（MFA）")
                {
                    let loginChecker = LoginChecker()
                    Task
                    {
                        do
                        {
                            print("🚀 开始测试 CAS 登录 + MFA...")
                            let result = try await loginChecker.checkLogin(
                                username: userinfo.username,
                                password: userinfo.encryptedPasswordSchool,
                                mfaCodeProvider: { phone in
                                    await requestMFACode(maskedPhone: phone)
                                }
                            )
                            print("✅ CAS 登录结果: \(result)")
                        }
                        catch
                        {
                            debugPrintError(error)
                        }
                    }
                }

                Button("测试南湖跑查询接口")
                {
                    let nanhurunquery: GymCloudQuery = GymCloudQuery()
                    Task
                    {
                        do
                        {
                            print("🚀 开始测试南湖跑接口...")
                            let cookie = try await nanhurunquery.loginAndGetRunCookie(
                                username: userinfo.username,
                                rsaPassword: userinfo.encryptedPasswordSchool,
                                mfaCodeProvider: { phone in
                                    await requestMFACode(maskedPhone: phone)
                                }
                            )
                            print("✅ 成功获取 Cookie: \(cookie)")
                            let circles = try await nanhurunquery.fetchRunScores(cookie: cookie)
                            print(circles)
                        }
                        catch
                        {
                            debugPrintError(error)
                        }
                    }
                }

                // MARK: - 电费接口测试（保持原有逻辑）

                Button("测试电费查询接口")
                {
                    let electrictyquery: ElectricityQuery = ElectricityQuery()
                    Task
                    {
                        do
                        {
                            print("🚀 开始测试电费接口...")
                            let token = try await electrictyquery.loginAndGetToken(
                                username: userinfo.username,
                                rsaPassword: userinfo.encryptedPasswordSchool,
                                mfaCodeProvider: { phone in
                                    await requestMFACode(maskedPhone: phone)
                                }
                            )
                            print("✅ 成功获取 Token: \(token)")
                        }
                        catch
                        {
                            debugPrintError(error)
                        }
                    }
                }

                Spacer(minLength: 0)
                    .sheet(isPresented: $showWeb)
                    {
                        NavigationStack
                        {
                            WebView(url: loginURL, webViewRef: $webViewRef)
                                .navigationTitle("HZAU Login")
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar
                                {
                                    ToolbarItem(placement: .topBarTrailing)
                                    {
                                        Button("关闭") { showWeb = false }
                                    }
                                }
                        }
                    }
                    .sheet(isPresented: $showMFASheet)
                    {
                        MFACodeInputSheet(
                            maskedPhone: mfaMaskedPhone,
                            code: $mfaCode,
                            onCancel: {
                                resolveMFACode(nil)
                            },
                            onConfirm: {
                                resolveMFACode(mfaCode)
                            }
                        )
                    }
            }
        }
    }

    // MARK: - 统一错误打印

    private func debugPrintError(_ error: Error)
    {
        if let nsErr = error as? NSError
        {
            print("❌ 失败！错误域: \(nsErr.domain)  代码: \(nsErr.code)")
            print("   描述: \(nsErr.localizedDescription)")
            for (k, v) in nsErr.userInfo { print("   \(k): \(v)") }
        }
        else
        {
            print("❌ 未知错误: \(error)")
        }
    }

    @MainActor
    private func requestMFACode(maskedPhone: String?) async -> String?
    {
        mfaMaskedPhone = maskedPhone ?? ""
        mfaCode = ""
        showMFASheet = true

        return await withCheckedContinuation { continuation in
            mfaContinuation = continuation
        }
    }

    @MainActor
    private func resolveMFACode(_ value: String?)
    {
        mfaContinuation?.resume(returning: value?.trimmingCharacters(in: .whitespacesAndNewlines))
        mfaContinuation = nil
        showMFASheet = false
    }
}

#Preview
{
    DebugRoom()
        .environmentObject(userInfo())
}
