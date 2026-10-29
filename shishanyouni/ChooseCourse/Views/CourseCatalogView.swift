import Foundation
import SwiftUI

/// 选课主页的课程目录 UI。
/// 目录分页由滚动位置驱动：最后一项出现时调用 `onReachEnd`，不再需要网页上的“点击查看更多”。
struct CourseCatalogView: View
{
    @Binding var category: CourseCatalogCategory
    let semester: SelectedCourseSemester
    let overview: CourseSelectionOverview
    let appliedSearchText: String
    let courses: [CourseSearchResult]
    let isLoading: Bool
    let isLoadingMore: Bool
    let hasMore: Bool
    let errorMessage: String?
    let loadMoreError: String?
    let expandedCourseKey: String?
    let expandedTeachingClasses: [String: [CourseSearchResult]]
    let expandingCourseKey: String?
    let expandedCourseError: String?
    let onRetry: () -> Void
    let onReachEnd: () -> Void
    let onToggleExpansion: (CourseSearchResult) -> Void
    let onRetryExpansion: (CourseSearchResult) -> Void
    let onSelectTeachingClass: (CourseSearchResult) -> Void
    /// 已选状态来自同一会话刚刷新过的 ChoosedDisplay；目录只负责显示和转交退选确认，
    /// 最终退选前仍会在 CourseMutationService 里重新核验，绝不使用这里的旧 token 写入。
    let selectedCourseFor: (CourseSearchResult) -> SelectedCourse?
    let onRequestDrop: (SelectedCourse) -> Void

    var body: some View
    {
        Group
        {
            Section
            {
                CourseSelectionHeaderCard(overview: overview, semester: semester)
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 6, trailing: 12))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                // 用原生 Picker 保持类别选择的语义和辅助功能；五个名称用短标题避免
                // 在窄屏上把网页式按钮挤到不可读。
                Picker("课程类别", selection: $category)
                {
                    ForEach(CourseCatalogCategory.allCases)
                    { item in
                        Text(item.shortTitle).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .labelsHidden()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 6, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section
            {
                if isLoading, courses.isEmpty
                {
                    // 首屏加载提示由 ChooseCourseView 覆盖在页面正中；这里保留一行
                    // 占位，避免 List 在等待网络返回时短暂显示“没有课程”的空状态。
                    Color.clear
                        .frame(height: 1)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                else if let errorMessage
                {
                    catalogError(errorMessage)
                }
                else if let loadError = loadMoreError, courses.isEmpty
                {
                    catalogError(loadError)
                }
                else if courses.isEmpty
                {
                    VStack(spacing: 8)
                    {
                        Image(systemName: "tray")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text(appliedSearchText.isEmpty ? "暂时没有可选课程" : "没有找到匹配课程")
                            .font(.headline)
                        Text(appliedSearchText.isEmpty ? "当前类别没有返回课程，向下拉可以重试。" : "可修改搜索关键词后再次搜索。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                else
                {
                    ForEach(Array(courses.enumerated()), id: \.element.id)
                    { index, course in
                        let isExpanded = expandedCourseKey == course.catalogKey
                        CourseSearchResultRow(
                            course: course,
                            isExpanded: isExpanded,
                            teachingClasses: isExpanded ? (expandedTeachingClasses[course.catalogKey] ?? []) : [],
                            isLoadingTeachingClasses: expandingCourseKey == course.catalogKey,
                            detailError: isExpanded ? expandedCourseError : nil,
                            onToggle: { onToggleExpansion(course) },
                            onRetryDetails: { onRetryExpansion(course) },
                            onSelectTeachingClass: onSelectTeachingClass,
                            selectedCourseFor: selectedCourseFor,
                            onRequestDrop: onRequestDrop
                        )
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .onAppear
                        {
                            // SwiftUI 可能多次触发 onAppear；上层的 isLoadingMore 锁会
                            // 保证同一段区间只请求一次。
                            if index == courses.count - 1,
                               hasMore,
                               !isLoadingMore,
                               loadMoreError == nil
                            {
                                onReachEnd()
                            }
                        }
                    }

                    if let loadError = loadMoreError
                    {
                        VStack(spacing: 8)
                        {
                            Text(loadError)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("重试加载更多", action: onReachEnd)
                                .nativeGlassButtonStyle()
                                .controlSize(.small)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    else if isLoadingMore
                    {
                        HStack(spacing: 8)
                        {
                            ProgressView()
                            Text("正在加载更多课程…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    else if !hasMore
                    {
                        Text("已加载全部课程")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func catalogError(_ message: String) -> some View
    {
        VStack(spacing: 8)
        {
            Label("课程目录加载失败", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("重试", action: onRetry)
                .nativeGlassButtonStyle()
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}
