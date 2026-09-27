import Foundation
import BackgroundTasks
import UserNotifications

final class ElectricityBGTaskManager
{
    static let taskID = "cn.edu.hzau.shishanyouni.electricityCheck"
    static let shared = ElectricityBGTaskManager()

    private init() {}

    func register()
    {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskID, using: nil)
        { task in
            // 系统理论上会传入注册类型；不匹配时安全结束，避免后台任务崩溃。
            guard let refreshTask = task as? BGAppRefreshTask else
            {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleRefresh(refreshTask)
        }
    }

    func scheduleNext()
    {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 2 * 60 * 60)
        do
        {
            try BGTaskScheduler.shared.submit(request)
            print("✅ [电量] 后台任务已调度，2小时后执行")
        }
        catch
        {
            print("⚠️ [电量] 后台任务调度失败: \(error)")
        }
    }

    private func handleRefresh(_ task: BGAppRefreshTask)
    {
        task.expirationHandler = {
            print("⏰ [电量] 后台任务超时")
        }

        let defaults = UserDefaults.standard
        let username = defaults.string(forKey: "saved_username") ?? ""
        let roomId = defaults.string(forKey: "hzau_room_id") ?? ""
        let password = KeychainHelper.shared.get(for: username) ?? ""

        guard !username.isEmpty,
              !password.isEmpty,
              !roomId.isEmpty,
              let encryptedPassword = encryptSchoolPassword(password: password)
        else
        {
            scheduleNext()
            task.setTaskCompleted(success: true)
            return
        }

        let query = ElectricityQuery()
        Task
        {
            do
            {
                let token = try await query.loginAndGetToken(
                    username: username,
                    rsaPassword: encryptedPassword
                )
                let records = try await query.fetchElectricityAccount(
                    token: token,
                    roomId: roomId
                )
                if let record = records.first,
                   let balance = Double(record.balance)
                {
                    let key = "electricity_low_balance_notified"
                    let lastNotified = defaults.double(forKey: key)

                    if balance < 20, abs(lastNotified - balance) > 0.01
                    {
                        let content = UNMutableNotificationContent()
                        content.title = "电费余额不足"
                        content.body = "\(record.roomName) 余额 \(String(format: "%.2f", balance)) 元，请及时充值。"
                        content.sound = .default
                        let request = UNNotificationRequest(
                            identifier: "low_balance_\(roomId)",
                            content: content,
                            trigger: nil
                        )
                        try? await UNUserNotificationCenter.current().add(request)
                        defaults.set(balance, forKey: key)
                        print("✅ [电量] 后台通知已发送: \(balance) 元")
                    }
                }
            }
            catch
            {
                print("⚠️ [电量] 后台查询失败: \(error)")
            }

            scheduleNext()
            task.setTaskCompleted(success: true)
        }
    }
}
