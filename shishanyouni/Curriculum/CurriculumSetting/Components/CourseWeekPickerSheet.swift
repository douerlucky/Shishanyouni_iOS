import SwiftUI

/// 单独放进二级 Sheet 的周次选择器，让课程编辑页面不会被 30 个周次按钮撑得很长。
struct CourseWeekPickerSheet: View
{
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedWeeks: Set<Int>

    private let maxWeek = 30

    var body: some View
    {
        NavigationStack
        {
            ScrollView
            {
                VStack(alignment: .leading, spacing: 20)
                {
                    HStack
                    {
                        weekShortcut("本学期", weeks: Set(1 ... 20))
                        weekShortcut("1-11周", weeks: Set(1 ... 11))
                        weekShortcut("12-19周", weeks: Set(12 ... 19))
                    }
                    .frame(maxWidth: .infinity)

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible()), count: 7),
                        spacing: 10
                    )
                    {
                        ForEach(1 ... maxWeek, id: \.self)
                        { week in
                            Button
                            {
                                if selectedWeeks.contains(week)
                                {
                                    selectedWeeks.remove(week)
                                }
                                else
                                {
                                    selectedWeeks.insert(week)
                                }
                            }
                            label:
                            {
                                Text("\(week)")
                                    .font(.callout.weight(.medium))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .nativeGlassButtonStyle(prominent: selectedWeeks.contains(week), shape: .circle, fillsWidth: true)
                            .tint(appActionBlue)
                            .controlSize(.mini)
                            .frame(height: 38)
                        }
                    }

                    HStack
                    {
                        Button("仅保留单周")
                        {
                            selectedWeeks = selectedWeeks.filter { $0.isMultiple(of: 2) == false }
                        }

                        Button("仅保留双周")
                        {
                            selectedWeeks = selectedWeeks.filter { $0.isMultiple(of: 2) }
                        }

                        Spacer()

                        Button("清空", role: .destructive)
                        {
                            selectedWeeks.removeAll()
                        }
                    }
                    .nativeGlassButtonStyle()
                }
                .padding()
            }
            .navigationTitle("选择上课周次")
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

    private func weekShortcut(_ title: String, weeks: Set<Int>) -> some View
    {
        Button(title) { selectedWeeks = weeks }
            .nativeGlassButtonStyle()
            .font(.caption)
    }
}
