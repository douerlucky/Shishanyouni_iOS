import SwiftUI

/// 一张介绍某个 Widget 的卡片；`preview` 是缩小后的静态示意图，不读取真实课程或日程。
struct WidgetShowcaseCard<Preview: View>: View
{
    let title: String
    let subtitle: String
    let family: String
    private let preview: Preview

    init(
        title: String,
        subtitle: String,
        family: String,
        @ViewBuilder preview: () -> Preview
    )
    {
        self.title = title
        self.subtitle = subtitle
        self.family = family
        self.preview = preview()
    }

    var body: some View
    {
        HStack(spacing: 14)
        {
            preview
                .frame(width: 132, height: 86)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay
                {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 5)
            {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(family)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.indigo)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

/// 大号“课表”组件的缩小示意。
struct CurriculumWidgetThumbnail: View
{
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 5)

    var body: some View
    {
        VStack(alignment: .leading, spacing: 5)
        {
            HStack
            {
                Text("第 3 周")
                    .font(.system(size: 8, weight: .bold))
                Spacer()
                Text("9 月")
                    .font(.system(size: 7))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 2)
            {
                ForEach(["一", "二", "三", "四", "五"], id: \.self)
                { day in
                    Text(day)
                        .font(.system(size: 6, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 2)
            {
                ForEach(0 ..< 15, id: \.self)
                { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(courseColor(for: index).opacity(index.isMultiple(of: 3) ? 0.95 : 0.16))
                        .frame(height: 9)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(9)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    private func courseColor(for index: Int) -> Color
    {
        [Color.blue, .orange, .purple, .green, .pink][index % 5]
    }
}

/// 中号“近期日程”组件的缩小示意：明确日期、三条项目和余下数量。
struct PersonalScheduleWidgetThumbnail: View
{
    var body: some View
    {
        VStack(alignment: .leading, spacing: 4)
        {
            HStack
            {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)

                Text("近期日程")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize()

                Spacer()
                Text("今天 · 9月22日")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundStyle(.orange)
                    .fixedSize()
            }

            ForEach(["组会", "做微积分的作业", "打动森"], id: \.self)
            { title in
                HStack(spacing: 5)
                {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(.orange)
                        .frame(width: 2, height: 12)
                    Text(title)
                        .font(.system(size: 8, weight: .medium))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }

            Text("余下 2 条")
                .font(.system(size: 7, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }
}

/// 小号“下节课”组件的缩小示意。
struct NextCourseWidgetThumbnail: View
{
    var body: some View
    {
        // 缩略图只展示能够完整读出的示例信息；不把长文案硬塞成省略号。
        VStack(alignment: .leading, spacing: 3)
        {
            HStack
            {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("1小时20分后")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(.blue)
                    .fixedSize()
            }

            Text("软件工程A")
                .font(.system(size: 13, weight: .bold))
                .fixedSize()

            HStack(spacing: 5)
            {
                Image(systemName: "clock")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)

                Text("今天 10:00–11:40")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .fixedSize()

                Image(systemName: "person.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)

                Text("王颖")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }

            HStack(spacing: 4)
            {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)

                Text("三教 A303")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }

            Text("第 3-4 节")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.blue)
                .fixedSize()

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }
}

#Preview
{
    NavigationStack
    {
        WidgetSettingView()
            .environmentObject(IAPStore.preview(hasActiveSubscription: false))
    }
}
