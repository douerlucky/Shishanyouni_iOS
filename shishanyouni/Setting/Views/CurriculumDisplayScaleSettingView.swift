// 课表显示缩放设置。

import SwiftUI

struct CurriculumDisplayScaleSettingView: View
{
    @AppStorage(PreferenceKey.curriculumFontScale) private var curriculumFontScale: Double = 1.0
    @State private var draftScale: Double = 1.0

    private var previewScale: CGFloat
    {
        CGFloat(min(max(draftScale, 0.65), 1.5))
    }

    private var previewRowHeight: CGFloat
    {
        curriculumCellHeight(for: draftScale)
    }

    var body: some View
    {
        GeometryReader
        {
            geometry in

            // 从完整页面宽度计算真实课表的单日列宽，预览只占时段列和两列课程。
            let courseWidth = max(1, (geometry.size.width - curriculumGridPadding * 2 - curriculumTimeColumnWidth) / 7)

            List
            {
                Section("预览")
                {
                    HStack(alignment: .top, spacing: 0)
                    {
                        VStack(spacing: 0)
                        {
                            previewPeriod(1, start: "8:00", end: "8:45")
                            previewPeriod(2, start: "8:55", end: "9:40")
                            previewPeriod(3, start: "10:00", end: "10:45")
                            previewPeriod(4, start: "10:55", end: "11:40")
                        }
                        .frame(width: curriculumTimeColumnWidth)
                        .background(Color(.secondarySystemBackground).opacity(0.5), in: Capsule())
                        .overlay(Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 1))

                        VStack(spacing: 0)
                        {
                            previewCourseCard("Akie秋绘的直播鉴赏", room: "三教A126", teacher: "douer", color: .pink)
                            previewEmptyCell()
                            previewEmptyCell()
                        }
                        .frame(width: courseWidth)

                        VStack(spacing: 0)
                        {
                            previewEmptyCell()
                            previewEmptyCell()
                            previewCourseCard("douer_lucky教你玩DeepSeek", room: "四教A403", teacher: "douer", color: .green)
                        }
                        .frame(width: courseWidth)
                    }
                    .frame(width: curriculumTimeColumnWidth + courseWidth * 2)
                    // 保留最大预览高度，拖动时滑块不会随着上一行的高度上下移动。
                    .frame(height: (curriculumCellHeight(for: 1.5) + 2) * 4)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }

                Section
                {
                    VStack(alignment: .leading, spacing: 8)
                    {
                        Text("显示比例：\(Int((draftScale * 100).rounded()))%")
                            .font(.subheadline)
                        Slider(value: $draftScale, in: 0.65 ... 1.5, step: 0.05)
                        { isEditing in
                            // 拖动只更新本页预览，松手后再通知真实课表并保存。
                            if !isEditing { curriculumFontScale = draftScale }
                        }
                            .accessibilityLabel("课表显示比例")
                    }

                    Button("恢复默认比例")
                    {
                        draftScale = 1.0
                        curriculumFontScale = 1.0
                    }
                    .frame(maxWidth: .infinity)
                } header: {
                    Text("课表显示比例")
                } footer: {
                    Text("格子高度、时段和课程文字会一起变化。缩小比例可在一屏显示更多节次；点开课程仍可查看完整信息。")
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("调整课表显示比例")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear
        {
            draftScale = min(max(curriculumFontScale, 0.65), 1.5)
        }
        .onDisappear
        {
            curriculumFontScale = draftScale
        }
    }

    private func previewPeriod(_ number: Int, start: String, end: String) -> some View
    {
        VStack(spacing: 2 * previewScale)
        {
            Text("\(number)")
                .font(.system(size: CurriculumTypography.periodTitle * previewScale, weight: .medium, design: .rounded))
            Text(start)
                .font(.system(size: CurriculumTypography.periodTime * previewScale, design: .rounded))
            Text(end)
                .font(.system(size: CurriculumTypography.periodTime * previewScale, design: .rounded))
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .frame(height: previewRowHeight)
        .padding(.vertical, 1)
    }

    private func previewEmptyCell() -> some View
    {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemGray5).opacity(0.7))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08)))
            .frame(height: previewRowHeight)
            .padding(1)
    }

    private func previewCourseCard(
        _ title: String,
        room: String,
        teacher: String,
        color: Color
    ) -> some View
    {
        VStack(spacing: 4 * previewScale)
        {
            Spacer(minLength: 2 * previewScale)
            Text(title)
                .font(.system(size: CurriculumTypography.courseName * previewScale, weight: .bold))
                .lineLimit(4)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
            HStack(spacing: 2 * previewScale)
            {
                Image(systemName: "location.fill")
                    .font(.system(size: CurriculumTypography.courseDetail * min(previewScale, 1)))
                Text(room)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.center)
            }
            .font(.system(size: CurriculumTypography.courseDetail * previewScale))
            .frame(maxWidth: .infinity, alignment: .center)
            HStack(spacing: 2 * previewScale)
            {
                Image(systemName: "person.fill")
                    .font(.system(size: CurriculumTypography.courseDetail * min(previewScale, 1)))
                Text(teacher)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.center)
            }
            .font(.system(size: CurriculumTypography.courseDetail * previewScale))
            .frame(maxWidth: .infinity, alignment: .center)
            Spacer(minLength: 2 * previewScale)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity)
        .frame(height: previewRowHeight * 2 + 2)
        .background(color.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
        .padding(1)
    }
}

#Preview
{
    ProfileView()
        .environmentObject(userInfo())
        .environmentObject(IAPStore.preview(hasActiveSubscription: false))
}
