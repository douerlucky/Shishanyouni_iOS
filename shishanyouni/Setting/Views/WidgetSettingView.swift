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

                            Text("在主屏幕快速查看课表、下节课和近期日程")
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
                    title: "近期日程",
                    subtitle: "显示日期、三条近期日程和余下数量",
                    family: "中号组件"
                )
                {
                    PersonalScheduleWidgetThumbnail()
                }

                WidgetShowcaseCard(
                    title: "下节课",
                    subtitle: "小号看一节课，中号查看未来三节课程",
                    family: "小号 · 中号 · 锁屏矩形"
                )
                {
                    NextCourseWidgetThumbnail()
                }
            }

            Section("如何添加")
            {
                Label("长按主屏幕空白处，点击“编辑”后选择“添加小组件”。", systemImage: "hand.tap.fill")
                Label("搜索“狮山有你”，再选择课表、近期日程或下节课。", systemImage: "magnifyingglass")
                Label("锁屏长按“自定义” → “锁定屏幕” → “添加小组件”，选择“下节课”。", systemImage: "lock.fill")
                Label("开通校园通行证后，组件会自动刷新并显示内容。", systemImage: "arrow.triangle.2.circlepath")
            }


        }
        .navigationTitle("小组件")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}
