import SwiftUI

struct ITCView: View
{
    @EnvironmentObject var userinfo: userInfo
    @State private var courses: [ITC_Course] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    private var filteredCourses: [ITC_Course]
    {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty { return courses }
        return courses.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View
    {
        NavigationStack
        {
            Group
            {
                if isLoading
                {
                    ProgressView("正在登录并获取课程列表...")
                        .padding()
                }
                else if let error = errorMessage
                {
                    VStack(spacing: 16)
                    {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("重试")
                        {
                            Task { await loadCourses() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                else if courses.isEmpty
                {
                    VStack(spacing: 16)
                    {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        Text("ITC 课程列表")
                            .font(.title3)
                            .fontWeight(.bold)
                        Button("获取课程列表")
                        {
                            Task { await loadCourses() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                else
                {
                    ZStack
                    {
                        ScrollView
                        {
                            LazyVGrid(columns: columns, spacing: 12)
                            {
                                ForEach(filteredCourses)
                                { course in
                                    NavigationLink(destination: AssignmentsView(courseID: course.courseID, courseName: course.name))
                                    {
                                        CourseCard(course: course)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }
                        .refreshable { await loadCourses() }
                        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 90) }

                        // 与 AllCourseView 完全一致的底部悬浮搜索栏布局
                        VStack(spacing: 12)
                        {
                            Spacer()

                            HStack
                            {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)

                                TextField("搜索课程", text: $searchText)
                                    .focused($isSearchFocused)
                                    .submitLabel(.search)
                                    .onSubmit { isSearchFocused = false }

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
                            .glassBackground(cornerRadius: 32)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 25)
                    }
                }
            }
            .navigationTitle("ITC 课程")
            .toolbar
            {
                if !courses.isEmpty
                {
                    ToolbarItem(placement: .primaryAction)
                    {
                        Button(action: { Task { await loadCourses() } })
                        {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .tabBar)
        }
        .task
        {
            if courses.isEmpty { await loadCourses() }
        }
    }

    private func loadCourses() async
    {
        isLoading = true
        errorMessage = nil

        do
        {
            let result = try await ITCFetch.shared.loginAndFetchCourses(
                username: userinfo.username,
                rsaPassword: userinfo.encryptedPasswordSchool
            )
            await MainActor.run
            {
                courses = result
                isLoading = false
            }
        }
        catch
        {
            await MainActor.run
            {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

private struct CourseCard: View
{
    let course: ITC_Course

    // 根据课程名哈希分配一个固定的色调
    private var cardColor: Color
    {
        let palette: [Color] = [
            .blue, .purple, .pink, .orange, .teal, .green, .indigo, .cyan
        ]
        let idx = abs(course.courseID.hashValue) % palette.count
        return palette[idx]
    }

    var body: some View
    {
        VStack(alignment: .leading, spacing: 8)
        {
            // 课程图标
            ZStack
            {
                RoundedRectangle(cornerRadius: 10)
                    .fill(cardColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: iconName)
                    .font(.system(size: 16))
                    .foregroundColor(cardColor)
            }
            
            Spacer()

            Text(course.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(cardColor.opacity(0.2), lineWidth: 1)
        )
    }

    private var iconName: String
    {
        let name = course.name
        if name.contains("程序") || name.contains("编程") || name.contains("C语言") || name.contains("Python") || name.contains("Java") || name.contains("JAVA") { return "chevron.left.forwardslash.chevron.right" }
        if name.contains("数学") || name.contains("算法") || name.contains("数据结构") { return "function" }
        if name.contains("网络") { return "network" }
        if name.contains("操作系统") { return "cpu" }
        if name.contains("数字") || name.contains("逻辑") || name.contains("EDA") { return "waveform" }
        if name.contains("图像") || name.contains("图形") || name.contains("多媒体") { return "photo" }
        if name.contains("神经") || name.contains("深度") || name.contains("AI") || name.contains("人工智能") { return "brain.head.profile" }
        if name.contains("物联") { return "antenna.radiowaves.left.and.right" }
        if name.contains("编译") { return "doc.text.magnifyingglass" }
        if name.contains("嵌入") { return "memorychip" }
        if name.contains("组成原理") { return "memorychip" }
        return "book.closed.fill"
    }
}

#Preview {
    ITCView().environmentObject(userInfo())
}
