import Foundation
import SwiftUI

/// 从选课主页右上角进入的“已选科目”页面。
/// 课程目录和已选列表分开加载，打开选课主页时不会额外请求一次已选课程接口。
struct SelectedCourseListScreen: View
{
    let courses: [SelectedCourse]
    let unmatchedSchedules: [SelectedCourseScheduleEntry]
    let semester: SelectedCourseSemester
    let overview: CourseSelectionOverview
    let isLoading: Bool
    let errorMessage: String?
    let onRetry: () -> Void
    let onRefresh: () async -> Void
    let onDrop: (SelectedCourse) -> Void

    var body: some View
    {
        ZStack
        {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            List
            {
                SelectedCourseView(
                    courses: courses,
                    unmatchedSchedules: unmatchedSchedules,
                    semester: semester,
                    overview: overview,
                    isLoading: isLoading,
                    errorMessage: errorMessage,
                    onRetry: onRetry,
                    onDrop: onDrop
                )
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            if isLoading, courses.isEmpty
            {
                CourseCenteredLoadingOverlay(message: "正在读取已选课程…")
            }
        }
        .navigationTitle("已选科目")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar
        {
            ToolbarItemGroup(placement: .topBarTrailing)
            {
                NavigationLink
                {
                    CourseAvailabilityOverviewView(
                        courses: courses,
                        semester: semester,
                        supplementarySchedules: unmatchedSchedules
                    )
                }
                label:
                {
                    Image(systemName: "calendar.badge.clock")
                }
                .disabled(courses.isEmpty && unmatchedSchedules.isEmpty)
                .accessibilityLabel("空闲度概览")

                Button
                {
                    Task { await onRefresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
                .accessibilityLabel("刷新已选科目")
            }
        }
        .refreshable
        {
            await onRefresh()
        }
        .task
        {
            // 页面每次打开都重新核验一次，确保退选/网页端变更能马上反映。
            await onRefresh()
        }
    }
}
