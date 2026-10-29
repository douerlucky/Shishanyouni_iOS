////
////  GradeView.swift
////  shishanyouni
////
////  Created by douer_lucky on 2026/2/7.
////
//
//import SwiftUI
//
//struct GradeInquiry: View
//{
//    @EnvironmentObject var userinfo: userInfo
//    @State var Grades: [Grade] = []
////    @State private var isLoading = false
//
//    @State private var showAlert = false
//    @State private var alertMessage = ""
//    @State private var alertTitle = ""
//
//    @State var selectedYear = "2025"
//    @State var selectedTerm = "1" // 默认第一学期
//
//    let gradeService = GradeService()
//
//    var body: some View
//    {
//        ZStack(alignment: .bottom)
//        {
//            ZStack
//            {
//                Color(uiColor: .systemGroupedBackground)
//                    .ignoresSafeArea()
//
//                if Grades.isEmpty
//                {
//                    VStack
//                    {
//                        Spacer()
//                        Text("未查询到任何成绩")
//                            .font(.title2)
//                            .foregroundColor(.secondary)
//                        Spacer()
//                    }
//                    .frame(maxWidth: .infinity, maxHeight: .infinity)
//                    .blur(radius: isLoading ? 3 : 0)
//                }
//                else
//                {
//                    List(Grades) { item in
//                        GradeCard(grade: item)
//                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
//                            .listRowSeparator(.hidden)
//                            .listRowBackground(Color.clear)
//                    }
//                    .listStyle(.plain)
//                    .scrollContentBackground(.hidden)
//                    .background(Color.clear)
//                    .blur(radius: isLoading ? 3 : 0)
//                    .safeAreaInset(edge: .bottom)
//                    {
//                        Color.clear.frame(height: 90)
//                    }
//                }
//
//                if isLoading
//                {
//                    VStack(spacing: 15)
//                    {
//                        ProgressView()
//                            .scaleEffect(1.5)
//                            .tint(.blue)
//                        Text("正在查询成绩")
//                            .font(.subheadline)
//                            .foregroundColor(.secondary)
//                    }
//                    .frame(width: 180, height: 120)
//                    .background(Color(.systemBackground).opacity(0.95))
//                    .cornerRadius(15)
//                    .shadow(radius: 10)
//                }
//            }
//
//            BottomButtonView(
//                isLoading: $isLoading,
//                Grades: $Grades,
//                showAlert: $showAlert,
//                alertTitle: $alertTitle,
//                alertMessage: $alertMessage,
//                selectedYear: $selectedYear,
//                selectedTerm: $selectedTerm,
//                gradeService: gradeService
//            )
//        }
//        .navigationTitle("成绩查询")
//        .toolbar(.hidden, for: .tabBar)
//        .navigationBarTitleDisplayMode(.large)
//        .alert(alertTitle, isPresented: $showAlert)
//        {
//            Button("好的", role: .cancel) { }
//        } message: {
//            Text(alertMessage)
//        }
//    }
//}
//
//// MARK: - 成绩卡片
//
//struct GradeCard: View
//{
//    let grade: Grade
//
//    var body: some View
//    {
//        VStack(spacing: 8)
//        {
//            // 课程名称 + 课程性质标签
//            HStack(alignment: .firstTextBaseline)
//            {
//                Text(grade.kcmc)
//                    .font(.title2)
//                    .fontWeight(.semibold)
//                Spacer()
//                if let type = grade.kcxzmc, !type.isEmpty
//                {
//                    Text(type)
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                        .padding(.horizontal, 8)
//                        .padding(.vertical, 3)
//                        .background(Color(.tertiarySystemFill))
//                        .clipShape(Capsule())
//                }
//            }
//
//            // 成绩 / 学分 / 绩点
//            HStack
//            {
//                GradeStatColumn(value: grade.cj,  label: "成绩")
//                Spacer()
//                GradeStatColumn(value: grade.xf,  label: "学分")
//                Spacer()
//                GradeStatColumn(value: grade.jd,  label: "绩点")
//            }
//            .padding(.horizontal, 12)
//
//        }
//        .frame(maxWidth: .infinity)
//        .padding(.vertical, 12)
//        .padding(.horizontal, 16)
//        .background(
//            RoundedRectangle(cornerRadius: 20)
//                .fill(Color(uiColor: .secondarySystemGroupedBackground))
//                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
//        )
//    }
//}
//
//private struct GradeStatColumn: View
//{
//    let value: String
//    let label: String
//
//    var body: some View
//    {
//        VStack(spacing: 2)
//        {
//            Text(value)
//                .font(.title3)
//                .fontWeight(.medium)
//            Text(label)
//                .font(.footnote)
//                .foregroundColor(.secondary)
//        }
//    }
//}
//
//// MARK: - 底部浮动按钮栏
//
//struct BottomButtonView: View
//{
//    @Binding var isLoading: Bool
//    @Binding var Grades: [Grade]
//    @Binding var showAlert: Bool
//    @Binding var alertTitle: String
//    @Binding var alertMessage: String
//    @Binding var selectedYear: String
//    @Binding var selectedTerm: String
//    @State private var showPicker = false
//    @EnvironmentObject var userinfo: userInfo
//    let gradeService: GradeService
//
//    let years = ["2022", "2023", "2024", "2025"]
//    let terms = [("第一学期", "1"), ("第二学期", "2")]
//
//    var body: some View
//    {
//        HStack(spacing: 15)
//        {
//            // 学期选择按钮
//            Button(action: { showPicker = true })
//            {
//                HStack
//                {
//                    Text("\(formatYearAbbreviation(selectedYear)) \(selectedTerm == "1" ? "一" : "二")")
//                        .font(.system(size: 14, weight: .bold))
//                    Image(systemName: "chevron.up")
//                        .font(.system(size: 10, weight: .bold))
//                }
//            }
//            .padding(.horizontal, 16)
//            .padding(.vertical, 10)
//            .background(Color(.systemBackground).opacity(0.9))
//            .clipShape(Capsule())
//            .optionalLiquidGlass()
//
//            // 查询按钮
//            Button(action: {
//                isLoading = true
//                Task
//                {
//                    defer { isLoading = false }
//                    do
//                    {
//                        Grades = try await gradeService.fetchGrades(
//                            username: userinfo.username,
//                            password: userinfo.plainPassword,
//                            xnm: selectedYear,
//                            xqm: selectedTerm
//                        )
//                        await MainActor.run
//                        {
//                            alertTitle   = "查询成功"
//                            alertMessage = "一共找到了 \(Grades.count) 门课的成绩"
//                            showAlert    = true
//                            UINotificationFeedbackGenerator().notificationOccurred(.success)
//                        }
//                    }
//                    catch
//                    {
//                        await MainActor.run
//                        {
//                            alertTitle   = "哎呀，出错了"
//                            if(userinfo.username.isEmpty && userinfo.plainPassword.isEmpty)
//                            {
//                                self.alertMessage = "好像忘记了登录，请先去登录吧！"
//                            }
//                            else
//                            {
//                                alertMessage = error.localizedDescription
//                            }
//                            UINotificationFeedbackGenerator().notificationOccurred(.error)
//                            showAlert    = true
//                        }
//                    }
//                }
//            })
//            {
//                Text("查询")
//                    .font(.system(size: 15, weight: .bold))
//                    .foregroundColor(.white)
//                    .padding(.horizontal, 24)
//                    .padding(.vertical, 10)
//                    .background(Color.blue)
//                    .clipShape(Capsule())
//            }
//            .optionalLiquidGlass()
//            .clipShape(Capsule())
//
//            // 统计按钮（预留）
//            Button(action: { print("去统计页") })
//            {
//                Image(systemName: "chart.bar.fill")
//                    .font(.system(size: 15, weight: .bold))
//                    .padding(.horizontal, 12)
//                    .padding(.vertical, 10)
//                    .background(Color.blue.opacity(0.15))
//                    .foregroundColor(.blue)
//                    .clipShape(Capsule())
//            }
//            .optionalLiquidGlass()
//        }
//        .padding(.vertical, 12)
//        .padding(.horizontal, 15)
//        .glassBackground(cornerRadius: 64)
//        .padding(.horizontal, 20)
//        .padding(.bottom, 25)
//        .sheet(isPresented: $showPicker)
//        {
//            VStack
//            {
//                Text("选择学期")
//                    .font(.headline)
//                    .padding(.top)
//
//                HStack(spacing: 0)
//                {
//                    Picker("年份", selection: $selectedYear)
//                    {
//                        ForEach(years, id: \.self) { year in
//                            if let y = Int(year)
//                            {
//                                Text("\(year)-\(String(y + 1))学年").tag(year)
//                            }
//                            else
//                            {
//                                Text("\(year)学年").tag(year)
//                            }
//                        }
//                    }
//                    .pickerStyle(.wheel)
//
//                    Picker("学期", selection: $selectedTerm)
//                    {
//                        ForEach(terms, id: \.1) { Text($0.0).tag($0.1) }
//                    }
//                    .pickerStyle(.wheel)
//                }
//
//                Button("确定") { showPicker = false }
//                    .optionalLiquidGlass()
//                    .buttonStyle(.borderedProminent)
//                    .padding(.bottom)
//            }
//            .presentationDetents([.height(300)])
//        }
//    }
//
//    private func formatYearAbbreviation(_ year: String) -> String
//    {
//        if let y = Int(year)
//        {
//            return String(format: "%02d-%02d", y % 100, (y + 1) % 100)
//        }
//        return year
//    }
//}
//
//#Preview
//{
//    GradeInquiry()
//        .environmentObject(userInfo())
//}
