//
//  WidgetSettingView.swift
//  shishanyouni
//
//  向用户介绍可添加的桌面小组件；真正的组件由 iOS 主屏幕管理。
//

import SwiftUI


struct WidgetSettingView: View
{
    @EnvironmentObject private var iapStore: IAPStore

    var body: some View
    {
        List
        {
            Section
            {
                VStack(alignment: .leading, spacing: 12)
                {
                    HStack(spacing: 12)
                    {
                        Image(systemName: "widget.large.badge.plus")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(Color.indigo, in: RoundedRectangle(cornerRadius: 14))

                        VStack(alignment: .leading, spacing: 3)
                        {
                            Text("桌面小组件")
                                .font(.system(size: 20, weight: .bold, design: .rounded))

                            Text("在主屏幕快速查看课表、下节课和下一条安排")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Label
                    {
                        Text(iapStore.hasActiveSubscription
                            ? "校园通行证已生效，可添加并显示组件内容"
                            : "小组件属于校园通行证权益")
                    }
                    icon:
                    {
                        Image(systemName: iapStore.hasActiveSubscription ? "checkmark.seal.fill" : "lock.fill")
                    }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(iapStore.hasActiveSubscription ? .green : .orange)
                }
                .padding(.vertical, 6)
            }

            if !iapStore.hasActiveSubscription
            {
                Section
                {
                    NavigationLink
                    {
                        SubscriptionView()
                    }
                    label:
                    {
                        Label("开通校园通行证", systemImage: "crown.fill")
                            .foregroundStyle(.primary)
                    }
                }
            }

            Section("可用组件")
            {
                WidgetShowcaseCard(
                    title: "课表",
                    subtitle: "完整显示当前周课表",
                    family: "大号组件"
                )
                {
                    CurriculumWidgetThumbnail()
                }

                WidgetShowcaseCard(
                    title: "下一条安排",
                    subtitle: "显示个人日程或校历中的下一条事项",
                    family: "中号组件"
                )
                {
                    PersonalScheduleWidgetThumbnail()
                }

                WidgetShowcaseCard(
                    title: "下节课",
                    subtitle: "显示当前课程或未来 2 天内的下一门课程",
                    family: "小号组件 · 锁屏矩形"
                )
                {
                    NextCourseWidgetThumbnail()
                }
            }

            Section("如何添加")
            {
                Label("长按主屏幕空白处，点击“编辑”后选择“添加小组件”。", systemImage: "hand.tap.fill")
                Label("搜索“狮山有你”，再选择课表或下一条安排。", systemImage: "magnifyingglass")
                Label("锁屏长按“自定义” → “锁定屏幕” → “添加小组件”，选择“下节课”。", systemImage: "lock.fill")
                Label("开通校园通行证后，组件会自动刷新并显示内容。", systemImage: "arrow.triangle.2.circlepath")
            }


        }
        .navigationTitle("小组件")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 一张介绍某个 Widget 的卡片；`preview` 是缩小后的静态示意图，不读取真实课程或日程。
private struct WidgetShowcaseCard<Preview: View>: View
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
private struct CurriculumWidgetThumbnail: View
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

/// 中号“下一条安排”组件的缩小示意。
private struct PersonalScheduleWidgetThumbnail: View
{
    var body: some View
    {
        VStack(alignment: .leading, spacing: 7)
        {
            HStack
            {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)

                Text("日程")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize()

                Spacer()
                Text("个人")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundStyle(.orange)
                    .fixedSize()
            }

            HStack(spacing: 7)
            {
                Image(systemName: "checklist")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 27, height: 27)
                    .background(.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 3)
                {
                    Text("项目组会议")
                        .font(.system(size: 11, weight: .semibold))
                        .fixedSize()
                    Text("10:00 · 1 小时后")
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                        .fixedSize()
                    Text("逸夫楼 C302")
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }
}

/// 小号“下节课”组件的缩小示意。
private struct NextCourseWidgetThumbnail: View
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
                Text("1 小时后")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(.blue)
                    .fixedSize()
            }

            Text("编译原理")
                .font(.system(size: 13, weight: .bold))
                .fixedSize()

            HStack(spacing: 5)
            {
                Image(systemName: "clock")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)

                Text("10:00")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .fixedSize()

                Image(systemName: "person.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)

                Text("张老师")
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
