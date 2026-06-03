//
//  CurriculumWidgetSetting.swift
//  shishanyouni
//
//  课表小组件设置。
//

import SwiftUI
import WidgetKit

struct CurriculumWidgetSettingView: View
{
    @EnvironmentObject var iapStore: IAPStore
    @Environment(\.dismiss) private var dismiss

    @State private var isCurriculumPluginOn = WidgetSharedStore.loadCurriculumPluginEnabled()
    @State private var navigateToSubscription = false

    private var canUseWidget: Bool
    {
        iapStore.hasActiveSubscription
    }

    var body: some View
    {
        List
        {
            Section
            {
                VStack(alignment: .leading, spacing: 14)
                {
                    HStack(spacing: 12)
                    {
                        Image(systemName: "widget.small.badge.plus")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 46, height: 46)
                            .background(Color(red: 23 / 255, green: 144 / 255, blue: 204 / 255), in: RoundedRectangle(cornerRadius: 14))

                        VStack(alignment: .leading, spacing: 4)
                        {
                            Text("课表小组件")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                            Text("在桌面显示当前周课表。")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }

                    Text("开启后，App 会把课表、当前周、背景设置同步到小组件，并刷新桌面小组件。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section
            {
                Toggle(isOn: widgetEnabledBinding)
                {
                    VStack(alignment: .leading, spacing: 4)
                    {
                        Text("启用课表小组件")
                        Text(canUseWidget ? "已满足校园通行证要求" : "需要先开通校园通行证")
                            .font(.footnote)
                            .foregroundColor(canUseWidget ? .secondary : .orange)
                    }
                }
                .tint(Color(red: 23 / 255, green: 144 / 255, blue: 204 / 255))

                if !canUseWidget
                {
                    Button
                    {
                        navigateToSubscription = true
                    }
                    label:
                    {
                        Label("开通校园通行证", systemImage: "crown.fill")
                    }
                }
            } footer: {
                Text("小组件读取的是共享课表数据。修改课程、背景、开学时间或当前周后，App 会自动请求刷新小组件。")
            }
        }
        .navigationTitle("小组件设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar
        {
            ToolbarItem(placement: .confirmationAction)
            {
                Button("完成") { dismiss() }
            }
        }
        .onAppear
        {
            isCurriculumPluginOn = WidgetSharedStore.loadCurriculumPluginEnabled()
            if !canUseWidget, isCurriculumPluginOn
            {
                setWidgetEnabled(false)
            }
        }
        .sheet(isPresented: $navigateToSubscription)
        {
            SubscriptionView()
        }
    }

    private var widgetEnabledBinding: Binding<Bool>
    {
        Binding(
            get: { isCurriculumPluginOn },
            set: { newValue in
                if newValue, !canUseWidget
                {
                    navigateToSubscription = true
                    setWidgetEnabled(false)
                    return
                }

                setWidgetEnabled(newValue)
            }
        )
    }

    private func setWidgetEnabled(_ enabled: Bool)
    {
        isCurriculumPluginOn = enabled
        WidgetSharedStore.saveCurriculumPluginEnabled(enabled)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetSharedStore.widgetKind)
    }
}

struct CurriculumWidgetSetting: View
{
    var body: some View
    {
        CurriculumWidgetSettingView()
    }
}

#Preview
{
    NavigationStack
    {
        CurriculumWidgetSettingView()
            .environmentObject(IAPStore.preview(hasActiveSubscription: false))
    }
}
