import Foundation
import SwiftUI

struct AvailabilityLegend: View
{
    let color: Color
    let title: String

    var body: some View
    {
        HStack(spacing: 5)
        {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 14, height: 14)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct CourseAvailabilitySlotDetailView: View
{
    @Environment(\.dismiss) private var dismiss

    let slot: CourseAvailabilitySlot

    var body: some View
    {
        NavigationStack
        {
            List
            {
                Section
                {
                    Text("第 \(slot.week) 周 · \(Self.weekdayTitles[slot.weekday - 1]) · 第 \(slot.period) 节")
                        .font(.headline)
                }

                Section("课程与地点")
                {
                    ForEach(slot.entries)
                    { entry in
                        VStack(alignment: .leading, spacing: 8)
                        {
                            Text(entry.courseName)
                                .font(.headline)

                            if let teachingClassName = entry.teachingClassName
                            {
                                Text(teachingClassName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Label(entry.timeText, systemImage: "calendar")
                            Label(entry.location, systemImage: "mappin.and.ellipse")

                            if let teacher = entry.teacher
                            {
                                Label(teacher, systemImage: "person.fill")
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("课程详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar
            {
                ToolbarItem(placement: .confirmationAction)
                {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private static let weekdayTitles = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
}
