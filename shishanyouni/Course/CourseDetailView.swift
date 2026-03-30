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
                                Text(course.kch)
                                    .monospaced()
                                    .foregroundColor(.secondary)
                                    .textSelection(.enabled)
                                Text(course.kkbmmc ?? "未知单位")
                                    .foregroundColor(.secondary)
                            }
                            .font(.subheadline)
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
                                ClassGroupCard(jxbmc: first.jxbmc, infos: classInfos)
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
    }

    private func fetchData()
    {
        Task
        {
            do
            {
                let cookie = try await scheduleQuery.loginAndGetCookie(
                    username: userinfo.username,
                    rsaPassword: userinfo.encryptedPasswordSchool
                )
                // 使用 AllCourseQuery 里的新方法进行 POST 请求
                let results = try await AllCourseQuery.shared.fetchCourseClasses(
                    cookie: cookie,
                    xnm: course.xnm,
                    xqm: course.xqm,
                    kch_id: course.kch_id
                )

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
}

// MARK: - 教学班分组卡片视图

struct ClassGroupCard: View
{
    let jxbmc: String
    let infos: [CourseClassInfo]

    var body: some View
    {
        VStack(alignment: .leading, spacing: 0)
        {
            // Header: 教学班名称和选课人数
            HStack
            {
                Text(jxbmc)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.blue)
                Spacer()
            }
            .padding()
            .background(Color.blue.opacity(0.05))

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
                .padding(.horizontal)
                .padding(.top, 8)
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
                        .lineLimit(1) // 防止文字过长换行破坏胶囊形状
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .foregroundColor(.secondary)
                .background(
                    Capsule()
                        .fill(Color.secondary.opacity(0.1)) // 淡淡的灰色背景
                )
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

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

#Preview
{
    NavigationStack
    {
        CourseDetailView(course: CourseInfo(row_id: "1", kch_id: "C46C66E5119F258DE053868F45D3567E", kch: "317300007046", kcmc: "计算机组成与结构", kkbmmc: "信息学院", kclbmc: "必修", xnm: "2025", xqm: "12", kcxzmc: "专业课"))
            .environmentObject(userInfo())
    }
}
