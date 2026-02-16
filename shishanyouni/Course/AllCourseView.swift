//
//  AllCourseView.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/15.
//

import SwiftUI

struct AllCourseView: View
{
    @EnvironmentObject var userinfo: userInfo
    @State private var searchText: String = ""
    @State private var courses: [CourseInfo] = []
    @State private var isLoading = false
    @FocusState private var isSearchFocused: Bool

    // MARK: - Filter States

    @State var selectedYear = "2025"
    @State var selectedTerm = "12"
    @State private var showPicker = false

    let years = ["2023", "2024", "2025", "2026"]
    let terms = [("秋季学期", "3"), ("春季学期", "12")]

    private let scheduleQuery = ScheduleQuery()

    var body: some View
    {
        NavigationStack
        {
            // 遮罩
            ZStack()
            {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

               

                Group
                {
                    if courses.isEmpty && !isLoading
                    {
                        VStack(spacing: 16)
                        {
                            Spacer()
                            Image(systemName: "magnifyingglass.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.blue)
                                .opacity(0.8)

                            VStack(spacing: 5)
                            {
                                Text(searchText.isEmpty ? "全校课程查询" : "未找到相关课程")
                                    .font(.title3)
                                    .fontWeight(.bold)

                                Text(searchText.isEmpty ? "在下方输入框开始查询" : "换个关键词，或者切换学期试试看吧")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                    else
                    {
                        List(courses)
                        { course in
                            ZStack
                            {
                                NavigationLink(destination: CourseDetailView(course: course))
                                {
                                    EmptyView()
                                }
                                .opacity(0)
                                AllCourseCardRow(course: course)
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        // 为底部的悬浮组件留出安全区域，防止遮挡
                        .safeAreaInset(edge: .bottom)
                        {
                            Color.clear.frame(height: 110)
                        }
                    }
                }

                VStack(spacing: 12) // 控制气泡和搜索框之间的间距
                {
                    Spacer() // 整体推到底部

                    // 1. 学期选择气泡
                    Button(action: { showPicker = true })
                    {
                        HStack(spacing: 6)
                        {
                            Image(systemName: "calendar")
                            Text("\(formatYearAbbreviation(selectedYear)) \(termShortName(selectedTerm))")
                            Image(systemName: "chevron.up")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                        // 建议在这里加一点点阴影，防止在 List 上看不清
                        .shadow(color: Color.black.opacity(0.05), radius: 4, y: 2)
                    }

                    // 2. 底部搜索框
                    HStack
                    {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)

                        TextField("输入课程名称或代码", text: $searchText)
                            .focused($isSearchFocused)
                            .submitLabel(.search)
                            .onSubmit { performSearch() }

                        if !searchText.isEmpty
                        {
                            Button(action: { searchText = "" })
                            {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .glassBackground(cornerRadius: 32) // 建议 cornerRadius 不要设太大，64 有点太圆了
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 25) // 这里的 padding 控制整个组件离屏幕底部的距离
                if isLoading
                {
                    ProgressView()
                        .padding(20)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .offset(y: -100)
                }

               
            }
            .navigationTitle("课程搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .sheet(isPresented: $showPicker)
            {
                VStack(spacing: 20)
                {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 40, height: 5)
                        .padding(.top, 10)

                    Text("选择查询学期")
                        .font(.headline)

                    HStack(spacing: 0)
                    {
                        Picker("年份", selection: $selectedYear)
                        {
                            ForEach(years, id: \.self)
                            { year in
                                if let yearInt = Int(year)
                                {
                                    Text("\(year)-\(String(yearInt + 1))学年").tag(year)
                                }
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 180)

                        Picker("学期", selection: $selectedTerm)
                        {
                            ForEach(terms, id: \.1) { Text($0.0).tag($0.1) }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 150)
                    }

                    Button(action: {
                        showPicker = false
                        if !searchText.isEmpty { performSearch() }
                    })
                    {
                        Text("确定")
                            .font(.system(size: 17, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 25)
                    .padding(.bottom, 20)
                }
                .presentationDetents([.height(350)])
            }
        }
    }

    // MARK: - Logic Functions

    func performSearch()
    {
        guard !searchText.isEmpty else { return }
        isLoading = true
        isSearchFocused = false

        Task
        {
            do
            {
                let cookie = try await scheduleQuery.loginAndGetCookie(
                    username: userinfo.username,
                    rsaPassword: userinfo.encryptedResult
                )

                let result = try await AllCourseQuery.shared.fetchAllCourses(
                    cookie: cookie,
                    xnm: selectedYear,
                    xqm: selectedTerm,
                    kch: searchText
                )

                await MainActor.run
                {
                    withAnimation(.spring())
                    {
                        self.courses = result
                    }
                    self.isLoading = false
                }
            }
            catch
            {
                print("AllCourse查询失败: \(error)")
                await MainActor.run { self.isLoading = false }
            }
        }
    }

    private func formatYearAbbreviation(_ year: String) -> String
    {
        if let yearInt = Int(year)
        {
            return String(format: "%02d-%02d", yearInt % 100, (yearInt + 1) % 100)
        }
        return year
    }

    private func termShortName(_ term: String) -> String
    {
        switch term
        {
        case "3": return "秋季"
        case "12": return "春季"
        default: return "未知"
        }
    }
}

struct AllCourseCardRow: View
{
    let course: CourseInfo

    var body: some View
    {
        VStack(alignment: .leading, spacing: 12)
        {
            HStack(alignment: .top)
            {
                Text(course.kcmc)
                    .font(.system(size: 18, weight: .bold))
                    .textSelection(.enabled)
                Spacer()
                Text(course.kch)
                    .font(.caption)
                    .monospacedDigit()
                    .padding(4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
                    .textSelection(.enabled)
            }

            VStack(alignment: .leading, spacing: 8)
            {
                HStack(spacing: 5)
                {
                    Image(systemName: "graduationcap.circle.fill")
                        .foregroundColor(.blue)
                    Text(course.kkbmmc ?? "未知学院")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8)
                {
                    if let category = course.kclbmc
                    {
                        TagView(text: category, color: .orange)
                    }
                    if let nature = course.kcxzmc
                    {
                        TagView(text: nature, color: .green)
                    }
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .contentShape(Rectangle())
    }
}

struct TagView: View
{
    let text: String
    let color: Color

    var body: some View
    {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 0.5))
    }
}

#Preview
{
    AllCourseView()
        .environmentObject(userInfo())
}
