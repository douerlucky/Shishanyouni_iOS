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

    @State var cookieInput: String = ""

    @EnvironmentObject var userinfo: userInfo

    // 登录入口
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

//                Button("导出 Cookie（登录后点）")
//                {
//                    guard let web = webViewRef
//                    else
//                    {
//                        cookieInput = "WebView 还没创建"
//                        return
//                    }
//                    CookieUtil.getJSessionID(from: web)
//                    { js in
//                        // 🌟 核心修复：确保在主线程更新 UI，并安全处理 vm
//                        DispatchQueue.main.async
//                        {
//                            let result = js ?? "未找到 JSESSIONID"
//                            self.vm.globalCookie = result // 更新全局状态
//                            self.cookieInput = result // 更新本地显示（如果你还要用的话）
//                            print("Cookie 已更新: \(result)")
//                        }
//                    }
//                }

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
                        // 调用你在 RSA.swift 里写的函数

                        userinfo.performEncryption()
                        print("✅ 加密成功!")
                        print(userinfo.encryptedResult)
                    }
                    .buttonStyle(.bordered)

                    Button("设定该学号密码")
                    {
                        userinfo.performEncryption()
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

                // 替换 DebugRoom.swift 中的 "测试查询课表接口" 按钮代码为：

                Button("测试查询课表接口")
                {
                    let coursequery: ScheduleQuery = ScheduleQuery()
                    Task
                    {
                        do
                        {
                            print("🚀 开始测试课表接口...")
                            let result: String = try await coursequery.loginAndGetCookie(
                                username: userinfo.username,
                                rsaPassword: userinfo.encryptedResult
                            )
                            print("✅ 成功获取 Cookie: \(result)")

                            // 2. 查询课表
                            let courses = try await coursequery.fetchCourses(
                                cookie: result,
                                xnm: "2025", // 2025学年
                                xqm: "3" // 12=下学期，3=上学期
                            )

                            print("✅ 成功获取 \(courses.count) 门课程")

                            // 3. 遍历课程信息
                            for course in courses
                            {
                                print("""
                                   课程: \(course.kcmc)
                                   ID: \(course.jxb_id)
                                   时间: \(course.xqjmc ?? "周\(course.xqj)") \(course.formattedJcs)
                                   教室: \(course.cdmc ?? "无")
                                   老师: \(course.xm ?? "未知") (\(course.zcmc ?? ""))
                                   班级: \(course.classList.joined(separator: ", "))
                                   周次: \(course.zcd ?? "")
                                """)
                            }
                        }
                        catch let error as NSError
                        {
                            print("❌ 失败了！")
                            print("错误域: \(error.domain)")
                            print("错误代码: \(error.code)")
                            print("错误描述: \(error.localizedDescription)")
                            if let userInfo = error.userInfo as? [String: Any]
                            {
                                print("详细信息:")
                                for (key, value) in userInfo
                                {
                                    print("  \(key): \(value)")
                                }
                            }
                        }
                        catch
                        {
                            print("❌ 未知错误: \(error)")
                        }
                    }
                }
                
                Button("测试考试查询接口")
                {
                    let examquery: ExamQuery = ExamQuery()
                    let coursequery: ScheduleQuery = ScheduleQuery()
                    Task
                    {
                        do
                        {
                            print("测试成绩接口...")
                            let result: String = try await coursequery.loginAndGetCookie(
                                username: userinfo.username,
                                rsaPassword: userinfo.encryptedResult
                            )
                            print("成功获取 Cookie: \(result)")

                            // 2. 查询课表
                            let courses = try await examquery.fetchExams(
                                cookie: result,
                                xnm: "2025", // 2025学年
                                xqm: "3" // 12=下学期，3=上学期
                            )

                            print("成功获取 \(courses.count) 门考试")

                        }
                        catch let error as NSError
                        {
                            print("❌ 失败了！")
                            print("错误域: \(error.domain)")
                            print("错误代码: \(error.code)")
                            print("错误描述: \(error.localizedDescription)")
                            if let userInfo = error.userInfo as? [String: Any]
                            {
                                print("详细信息:")
                                for (key, value) in userInfo
                                {
                                    print("  \(key): \(value)")
                                }
                            }
                        }
                        catch
                        {
                            print("❌ 未知错误: \(error)")
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
                            print("测试成绩接口...")
                            let result: String = try await nanhurunquery.loginAndGetRunCookie(
                                username: userinfo.username,
                                rsaPassword: userinfo.encryptedResult
                            )
                            print("成功获取 Cookie: \(result)")
                            let circles = try await nanhurunquery.fetchRunScores(cookie: result)
                            print(circles)
                        }
                        catch let error as NSError
                        {
                            print("❌ 失败了！")
                            print("错误域: \(error.domain)")
                            print("错误代码: \(error.code)")
                            print("错误描述: \(error.localizedDescription)")
                            if let userInfo = error.userInfo as? [String: Any]
                            {
                                print("详细信息:")
                                for (key, value) in userInfo
                                {
                                    print("  \(key): \(value)")
                                }
                            }
                        }
                        catch
                        {
                            print("❌ 未知错误: \(error)")
                        }
                    }
                }
                
                Spacer(minLength: 0)
                    .sheet(isPresented: $showWeb)
                    {
                        NavigationStack
                        {
                            // 登录窗口
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
            }
        }
    }
}

#Preview
{
    DebugRoom()
        .environmentObject(userInfo())
}
