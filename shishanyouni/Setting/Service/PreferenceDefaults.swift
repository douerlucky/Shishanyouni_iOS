import Foundation

enum PreferenceDefaults
{
    static func register()
    {
        UserDefaults.standard.register(defaults: [
            PreferenceKey.prefShowClock: true,
            PreferenceKey.prefShowEnrollmentDays: true,
            PreferenceKey.prefShowNextEvent: true,
            PreferenceKey.appDisplayMode: AppDisplayMode.all.rawValue,
            PreferenceKey.showScheduleTab: true,
            PreferenceKey.showPersonalSchedule: true,
            PreferenceKey.showCampusPassFeatures: true,
            PreferenceKey.showCampusPassCard: true,
            PreferenceKey.enableLiquidGlassEffect: true,
            PreferenceKey.componentOpacity: 1.0,
            PreferenceKey.profileBackgroundEnabled: false,
        ])
    }

    static func applyDefaultEnabledMigrationIfNeeded()
    {
        guard !UserDefaults.standard.bool(forKey: PreferenceKey.didApplyDefaultEnabledMigration) else { return }

        UserDefaults.standard.set(true, forKey: PreferenceKey.prefShowClock)
        UserDefaults.standard.set(true, forKey: PreferenceKey.prefShowEnrollmentDays)
        UserDefaults.standard.set(true, forKey: PreferenceKey.prefShowNextEvent)
        UserDefaults.standard.set(true, forKey: PreferenceKey.enableLiquidGlassEffect)
        UserDefaults.standard.set(true, forKey: PreferenceKey.didApplyDefaultEnabledMigration)
    }
}
