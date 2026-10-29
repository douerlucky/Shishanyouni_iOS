import SwiftUI

struct ITCView: View
{
    @EnvironmentObject var userinfo: userInfo
    @State private var courses: [ITC_Course] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""

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
                        .nativeGlassButtonStyle(prominent: true)
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
                        .nativeGlassButtonStyle(prominent: true)
                    }
                }
                else
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
                }
            }
            .navigationTitle("ITC 课程")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "搜索课程"
            )
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
            let result = try await ITCAPI.shared.loginAndFetchCourses(
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
