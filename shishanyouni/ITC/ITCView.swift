import SwiftUI

struct ITCView: View
{
    @EnvironmentObject var userinfo: userInfo
    @State private var courses: [ITC_Course] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

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
                        Button("重试")
                        {
                            Task { await loadCourses() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
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
                    List(courses)
                    { course in
                        HStack
                        {
                            Text(course.name)
                                .font(.body)
                            Spacer()
                            Text("ID: \(course.courseID)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.insetGrouped)
                    .refreshable
                    {
                        await loadCourses()
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
        }
        .task
        {
            await loadCourses()
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
