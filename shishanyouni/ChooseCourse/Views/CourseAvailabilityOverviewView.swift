import Foundation
import SwiftUI

/// 从“已选科目”进入的课表占用概览。
/// 红色格子表示该周、该日、该节已有课程；灰色格子表示当前已选课程中没有安排。
struct CourseAvailabilityOverviewView: View
{
    private let semester: SelectedCourseSemester
    private let availability: CourseAvailabilityData

    @State private var selectedWeek: Int
    @State private var selectedSlot: CourseAvailabilitySlot?

    init(
        courses: [SelectedCourse],
        semester: SelectedCourseSemester,
        supplementarySchedules: [SelectedCourseScheduleEntry] = []
    )
    {
        let availability = CourseAvailabilityData(
            courses: courses,
            supplementarySchedules: supplementarySchedules
        )
        self.semester = semester
        self.availability = availability
        _selectedWeek = State(initialValue: availability.initialWeek)
    }

    var body: some View
    {
        ZStack
        {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView
            {
                VStack(spacing: 18)
                {
                    VStack(alignment: .leading, spacing: 5)
                    {
                        Text(semester.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("按周查看已选课程安排：红色为有课，灰色为空闲。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    weekSwitcher
                    availabilityGrid

                    HStack(spacing: 16)
                    {
                        AvailabilityLegend(color: .red, title: "已有课程")
                        AvailabilityLegend(color: .gray.opacity(0.32), title: "空闲")
                        Spacer()
                        Text("点按红色格子查看地点")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if !availability.hasBusySlot
                    {
                        VStack(spacing: 8)
                        {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("暂未识别到排课")
                                .font(.headline)
                            Text("当前已选课程没有可用于排课的上课时间。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }

                    if !availability.unparsedCourseNames.isEmpty
                    {
                        Label {
                            Text("以下课程的上课时间格式暂无法识别，未计入网格：\(availability.unparsedCourseNames.joined(separator: "、"))")
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("空闲度概览")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .sheet(item: $selectedSlot)
        { slot in
            CourseAvailabilitySlotDetailView(slot: slot)
        }
    }

    private var weekSwitcher: some View
    {
        HStack
        {
            NextButton(systemImage: "chevron.left", size: 38, prominent: false)
            {
                selectedWeek -= 1
            }
            .disabled(selectedWeek <= availability.weekRange.lowerBound)
            .accessibilityLabel("上一周")

            Spacer()

            VStack(spacing: 2)
            {
                Text("第 \(selectedWeek) 周")
                    .font(.title3.weight(.bold))
                Text("共 \(availability.weekRange.upperBound) 周")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            NextButton(systemImage: "chevron.right", size: 38, prominent: false)
            {
                selectedWeek += 1
            }
            .disabled(selectedWeek >= availability.weekRange.upperBound)
            .accessibilityLabel("下一周")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    private var availabilityGrid: some View
    {
        VStack(alignment: .leading, spacing: 12)
        {
            Text("第 \(selectedWeek) 周课表")
                .font(.headline.weight(.semibold))

            Grid(horizontalSpacing: 4, verticalSpacing: 4)
            {
                GridRow
                {
                    Color.clear
                        .frame(width: 24, height: 20)

                    ForEach(Array(Self.weekdayTitles.enumerated()), id: \.offset)
                    { _, title in
                        Text(title)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                ForEach(1 ... CourseAvailabilityData.periodCount, id: \.self)
                { period in
                    GridRow
                    {
                        Text("\(period)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                            .accessibilityLabel("第 \(period) 节")

                        ForEach(1 ... CourseAvailabilityData.weekdayCount, id: \.self)
                        { weekday in
                            availabilityCell(weekday: weekday, period: period)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    @ViewBuilder
    private func availabilityCell(weekday: Int, period: Int) -> some View
    {
        let entries = availability.entries(week: selectedWeek, weekday: weekday, period: period)

        if entries.isEmpty
        {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.gray.opacity(0.22))
                .frame(height: 29)
                .accessibilityLabel("第 \(selectedWeek) 周，\(Self.weekdayTitles[weekday - 1])，第 \(period) 节，空闲")
        }
        else
        {
            Button
            {
                selectedSlot = CourseAvailabilitySlot(
                    week: selectedWeek,
                    weekday: weekday,
                    period: period,
                    entries: entries
                )
            }
            label:
            {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.red)
                    .overlay
                    {
                        if entries.count > 1
                        {
                            Text("\(entries.count)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(height: 29)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("第 \(selectedWeek) 周，\(Self.weekdayTitles[weekday - 1])，第 \(period) 节，有 \(entries.count) 门课程")
        }
    }

    private static let weekdayTitles = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
}
