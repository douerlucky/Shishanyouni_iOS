//
//  GradeInquiry.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/7.
//

import SwiftUI

struct GradeInquiry: View
{
    @EnvironmentObject var userinfo: userInfo
    @State var cookie: String = ""
    @State var Grades: [Grade] = []

    @State private var isLoading = false // 是否加载

    // 弹窗
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""

    @State var selectedYear = "2025"
    @State var selectedTerm = "3" // 默认选秋季

    var gradeQuery: GradeQuery = GradeQuery() // 成绩查询器

    var body: some View
    {
        ZStack(alignment: .bottom)
        {
            ZStack
            {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                if Grades.count == 0
                {
                    VStack
                    {
                        Spacer()
                        Text("未查询到任何成绩")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .blur(radius: isLoading ? 3 : 0)
                }
                else
                {
                    List(Grades)
                    { item in
                        GradeCard(grade: item)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .blur(radius: isLoading ? 3 : 0)
                    // 给底部留出空隙，防止最后一个卡片被按钮遮住
                    .safeAreaInset(edge: .bottom)
                    {
                        Color.clear.frame(height: 90)
                    }
                }

                if isLoading
                {
                    VStack(spacing: 15)
                    {
                        ProgressView() // 苹果自带的菊花转动
                            .scaleEffect(1.5)
                            .tint(.blue)

                        Text("正在查询成绩")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 180, height: 120)
                    .background(Color(.systemBackground).opacity(0.95))
                    .cornerRadius(15)
                    .shadow(radius: 10)
                }
            }

            // 浮动按钮栏
            BottomButtonView(
                isLoading: $isLoading,
                Grades: $Grades,
                showAlert: $showAlert,
                alertTitle: $alertTitle,
                alertMessage: $alertMessage,
                selectedYear: $selectedYear,
                selectedTerm: $selectedTerm,
                gradeQuery: gradeQuery
            )
        }
        .navigationTitle("成绩查询")
        .toolbar(.hidden, for: .tabBar)
        .navigationBarTitleDisplayMode(.large)
        .alert(alertTitle, isPresented: $showAlert)
        {
            Button("好的", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
}

struct GradeCard: View
{
    let grade: Grade

    var body: some View
    {
        VStack(spacing: 8)
        {
            // 课程名称行
            HStack
            {
                Text(grade.kcmc)
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }

            // 成绩、学分、绩点详情行
            HStack
            {
                VStack
                {
                    Text(grade.cj)
                        .font(.title3)
                        .fontWeight(.medium)
                    Text("成绩")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack
                {
                    Text(grade.xf)
                        .font(.title3)
                        .fontWeight(.medium)
                    Text("学分")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack
                {
                    Text(grade.jd)
                        .font(.title3)
                        .fontWeight(.medium)
                    Text("绩点")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
}

struct BottomButtonView: View
{
    @Binding var isLoading: Bool
    @Binding var Grades: [Grade]
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    @Binding var selectedYear: String
    @Binding var selectedTerm: String
    @State private var showPicker = false
    @EnvironmentObject var userinfo: userInfo
    let gradeQuery: GradeQuery

    let years = ["2022", "2023", "2024", "2025"]
    let terms = [
        ("上学期", "3"),
        ("下学期", "12"),
    ]

    var body: some View
    {
        HStack(spacing: 15)
        {
            // 学期选择按钮
            Button(action: { showPicker = true })
            {
                HStack
                {
                    Text("\(formatYearAbbreviation(selectedYear)) \(selectedTerm == "3" ? "上" : "下")")
                        .font(.system(size: 14, weight: .bold))
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemBackground).opacity(0.9))
            .clipShape(Capsule())
            .optionalLiquidGlass()

            // 查询按钮
            Button(action: {
                print("查询中...")
                isLoading = true

                Task
                {
                    defer { isLoading = false }
                    do
                    {
                        let cookie = try await gradeQuery.loginAndGetCookie(username: userinfo.username, rsaPassword: userinfo.encryptedResult)
                        Grades = await gradeQuery.fetchGrades(cookie: cookie, xnm: selectedYear, xqm: selectedTerm)

                        await MainActor.run
                        {
                            // 成功弹窗
                            self.alertTitle = "查询成功"
                            self.alertMessage = "一共找到了 \(Grades.count) 门课的成绩"
                            self.showAlert = true
                        }
                    }
                    catch
                    {
                        print("出错了")
                        await MainActor.run
                        {
                            // 失败
                            self.alertTitle = "哎呀,出错了"
                            self.alertMessage = error.localizedDescription
                            self.showAlert = true
                        }
                    }
                }

            })
            {
                Text("查询")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
            .optionalLiquidGlass()
            .clipShape(Capsule())

            // 预留的统计按钮
            Button(action: { print("去统计页") })
            {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 15, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .clipShape(Capsule())
            }
            .optionalLiquidGlass()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 15)
        .glassBackground(cornerRadius: 64)
        .padding(.horizontal, 20)
        .padding(.bottom, 25)
        .sheet(isPresented: $showPicker)
        {
            VStack
            {
                Text("选择学期")
                    .font(.headline)
                    .padding(.top)

                HStack(spacing: 0)
                {
                    Picker("年份", selection: $selectedYear)
                    {
                        ForEach(years, id: \.self)
                        { year in
                            // 将字符串转为 Int 算下一年，再拼接起来
                            if let yearInt = Int(year)
                            {
                                Text("\(year)-\(String(yearInt + 1))学年")
                                    .tag(year)
                            }
                            else
                            {
                                Text("\(year)学年")
                                    .tag(year)
                            }
                        }
                    }
                    .pickerStyle(.wheel)

                    Picker("学期", selection: $selectedTerm)
                    {
                        ForEach(terms, id: \.1) { Text($0.0).tag($0.1) }
                    }
                    .pickerStyle(.wheel)
                }

                Button("确定")
                {
                    showPicker = false
                }
                .optionalLiquidGlass()
                .buttonStyle(.borderedProminent)
                .padding(.bottom)
                
            }
            .presentationDetents([.height(300)])
        }
        
    }

    private func formatYearAbbreviation(_ year: String) -> String
    {
        if let yearInt = Int(year)
        {
            let start = yearInt % 100 // 25
            let end = (yearInt + 1) % 100 // 26
            return String(format: "%02d-%02d", start, end)
        }
        return year
    }
}



#Preview
{
    let previewUserInfo = userInfo()
    GradeInquiry()
        .environmentObject(previewUserInfo)
}
