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

    private var isOSSupported: Bool
    {
        if #available(iOS 17.0, *)
        {
            return true
        }
        return false
    }

    private var canUseWidget: Bool
    {
        isOSSupported && iapStore.hasActiveSubscription
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
                        if !isOSSupported
                        {
                            Text("小组件要求 iOS 17.0 以上才能使用，请升级手机系统")
                                .font(.footnote)
                                .foregroundColor(.orange)
                        }
                        else if canUseWidget
                        {
                            Text("已满足校园通行证要求")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        else
                        {
                            Text("需要先开通校园通行证")
                                .font(.footnote)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .tint(Color(red: 23 / 255, green: 144 / 255, blue: 204 / 255))
                .disabled(!isOSSupported)

                if !isOSSupported
                {
                    HStack(spacing: 8)
                    {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("当前系统版本过低，小组件无法使用")
                            .font(.footnote)
                            .foregroundColor(.orange)
                    }
                }
                else if !canUseWidget
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
            if !isOSSupported
            {
                setWidgetEnabled(false)
            }
            else if !canUseWidget, isCurriculumPluginOn
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
                if newValue, !isOSSupported
                {
                    setWidgetEnabled(false)
                    return
                }
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
