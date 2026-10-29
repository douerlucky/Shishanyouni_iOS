import Combine
import EventKit
import SwiftUI

// MARK: - 考试卡片组件

struct ExamCard: View
{
    let exam: Exam
    @State private var isAddingToCalendar = false
    @State private var showCalendarAlert = false
    @State private var calendarAlertTitle = ""
    @State private var calendarAlertMessage = ""

    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View
    {
        VStack(alignment: .leading, spacing: 12)
        {
            HStack(alignment: .top)
            {
                VStack(alignment: .leading, spacing: 4)
                {
                    Text(exam.kcmc)
                        .font(.title2)
                        .foregroundColor(.primary)

                    Text(exam.ksmc)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
                Spacer()

                VStack(alignment: .trailing, spacing: 8)
                {
                    if let xf = exam.xf
                    {
                        Text("\(xf)学分")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    Button(action: {
                        Task { await addExamToCalendar() }
                    })
                    {
                        HStack(spacing: 5)
                        {
                            Image(systemName: isAddingToCalendar ? "hourglass" : "calendar.badge.plus")
                                .font(.system(size: 13, weight: .bold))
                            Text("日历")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(.blue)
                        .contentShape(Rectangle())
                    }
                    .nativeGlassButtonStyle()
                    .disabled(isAddingToCalendar)
                }
            }

            VStack(alignment: .leading, spacing: 8)
            {
                HStack
                {
                    Image(systemName: "calendar")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    Text(exam.examDate)
                        .font(.system(size: 20, weight: .semibold))
                    Text(exam.examTime)
                        .font(.system(size: 20, weight: .semibold))
                }

                HStack(spacing: 15)
                {
                    HStack
                    {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(.red)
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 16)
                        Text(exam.cdmc ?? "未指定场地")
                            .font(.system(size: 16, weight: .semibold))
                    }

                    HStack
                    {
                        Image(systemName: "number.square")
                            .foregroundColor(.green)
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 18)
                        Text(exam.seatDisplayText)
                            .font(.system(size: 16, weight: .semibold))
                    }
                }

                if let startDate = exam.examStartDate
                {
                    CountdownView(now: now, examStartDate: startDate)
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
        .onReceive(timer)
        { _ in
            now = Date()
        }
        .alert(calendarAlertTitle, isPresented: $showCalendarAlert)
        {
            Button("好的", role: .cancel) { }
        } message: {
            Text(calendarAlertMessage)
        }
    }

    @MainActor
    private func setCalendarAlert(title: String, message: String)
    {
        calendarAlertTitle = title
        calendarAlertMessage = message
        showCalendarAlert = true
    }

    @MainActor
    private func addExamToCalendar() async
    {
        isAddingToCalendar = true
        defer
        {
            isAddingToCalendar = false
        }

        do
        {
            let store = EKEventStore()
            let granted = try await requestCalendarAccess(store)
            guard granted
            else
            {
                setCalendarAlert(title: "无法添加", message: "需要允许访问系统日历，才可以帮你把考试安排塞进去哦。")
                return
            }

            let (startDate, endDate) = try parseExamDateRange()
            if hasExistingEvent(in: store, startDate: startDate, endDate: endDate)
            {
                setCalendarAlert(title: "已经添加过啦", message: "系统日历里已经有这场考试，不会重复添加。")
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                return
            }

            guard let calendar = store.defaultCalendarForNewEvents
            else
            {
                setCalendarAlert(title: "添加失败", message: "没有找到可以写入的默认日历。")
                return
            }

            let event = EKEvent(eventStore: store)
            event.title = exam.kcmc
            event.startDate = startDate
            event.endDate = endDate
            event.calendar = calendar
            event.location = examLocation
            event.notes = "考试类型：\(exam.ksmc)"
            event.alarms = [EKAlarm(relativeOffset: -24 * 60 * 60)]

            try store.save(event, span: .thisEvent, commit: true)
            setCalendarAlert(title: "添加成功", message: "已添加到系统日历，并设置为考前 1 天提醒。")
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        catch
        {
            setCalendarAlert(title: "添加失败", message: error.localizedDescription)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private var examLocation: String
    {
        let room = (exam.cdmc ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return room
    }

    private func requestCalendarAccess(_ store: EKEventStore) async throws -> Bool
    {
        try await withCheckedThrowingContinuation
        { continuation in
            if #available(iOS 17.0, *)
            {
                store.requestFullAccessToEvents
                { granted, error in
                    if let error
                    {
                        continuation.resume(throwing: error)
                    }
                    else
                    {
                        continuation.resume(returning: granted)
                    }
                }
            }
            else
            {
                store.requestAccess(to: .event)
                { granted, error in
                    if let error
                    {
                        continuation.resume(throwing: error)
                    }
                    else
                    {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }

    private func parseExamDateRange() throws -> (Date, Date)
    {
        guard let dateText = exam.examDate.firstMatch(of: #"\d{4}-\d{1,2}-\d{1,2}"#)
        else
        {
            throw CalendarAddError.invalidExamDate
        }

        let normalizedTime = exam.examTime
            .replacingOccurrences(of: "－", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
        let parts = normalizedTime
            .components(separatedBy: "-")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard parts.count >= 2
        else
        {
            throw CalendarAddError.invalidExamTime
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        guard let startDate = formatter.date(from: "\(dateText) \(parts[0])"),
              let endDate = formatter.date(from: "\(dateText) \(parts[1])"),
              endDate > startDate
        else
        {
            throw CalendarAddError.invalidExamTime
        }

        return (startDate, endDate)
    }

    private func hasExistingEvent(in store: EKEventStore, startDate: Date, endDate: Date) -> Bool
    {
        let predicate = store.predicateForEvents(
            withStart: startDate.addingTimeInterval(-60),
            end: endDate.addingTimeInterval(60),
            calendars: nil
        )

        return store.events(matching: predicate).contains
        { event in
            event.title == exam.kcmc
                && abs(event.startDate.timeIntervalSince(startDate)) < 60
                && abs(event.endDate.timeIntervalSince(endDate)) < 60
        }
    }
}

private struct CountdownView: View
{
    let now: Date
    let examStartDate: Date

    private var isPast: Bool { now >= examStartDate }

    private var components: DateComponents
    {
        Calendar.current.dateComponents([.day, .hour, .minute, .second], from: now, to: examStartDate)
    }

    private var displayText: String
    {
        guard let d = components.day, let h = components.hour, let m = components.minute, let s = components.second
        else
        {
            return ""
        }
        if isPast { return "考试已结束" }
        let totalHours = d * 24 + h
        if totalHours <= 0
        {
            if m <= 0
            {
                return "\(s)秒后"
            }
            return "\(m)分\(s)秒后"
        }
        if totalHours < 24
        {
            return "\(totalHours)时\(m)分后"
        }
        if d < 3
        {
            return "\(d)天\(h)时后"
        }
        return "还有\(d)天"
    }

    private var accentColor: Color
    {
        if isPast { return .secondary }
        guard let d = components.day, let h = components.hour, let m = components.minute
        else
        {
            return .secondary
        }
        let totalHours = d * 24 + h
        if totalHours <= 0 && m < 30 { return .red }
        if totalHours < 24 { return .orange }
        return .blue
    }

    private var iconName: String
    {
        if isPast { return "checkmark.circle.fill" }
        guard let d = components.day, let h = components.hour else { return "hourglass" }
        let totalHours = d * 24 + h
        if totalHours <= 0 { return "timer" }
        if totalHours < 72 { return "hourglass" }
        return "clock"
    }

    var body: some View
    {
        HStack(spacing: 6)
        {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .semibold))
            Text(displayText)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(accentColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(accentColor.opacity(0.1))
        .cornerRadius(8)
        .padding(.top, 2)
    }
}

private enum CalendarAddError: LocalizedError
{
    case invalidExamDate
    case invalidExamTime

    var errorDescription: String?
    {
        switch self
        {
        case .invalidExamDate:
            return "考试日期格式看起来不太对，暂时没法添加到日历。"
        case .invalidExamTime:
            return "考试时间格式看起来不太对，暂时没法添加到日历。"
        }
    }
}

private extension String
{
    func firstMatch(of pattern: String) -> String?
    {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: self, range: NSRange(startIndex..., in: self)),
              let range = Range(match.range, in: self)
        else
        {
            return nil
        }

        return String(self[range])
    }
}

#Preview
{
    ExamView()
        .environmentObject(userInfo())
}
