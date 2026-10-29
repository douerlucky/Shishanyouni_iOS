import Foundation

/// 编辑界面中的一个时间段草稿。
/// `source` 有值时表示它对应现有 Course，保存后必须保留其 id 和提醒状态。
struct CourseTimeSlotDraft: Identifiable
{
    let id: UUID
    let source: Course?
    var weekday: Int
    var startPeriod: Int
    var endPeriod: Int
    var weeks: Set<Int>

    init(source: Course)
    {
        id = UUID()
        self.source = source
        weekday = (1 ... 7).contains(source.day) ? source.day : 1
        startPeriod = source.hasScheduledTime ? source.start : 1
        endPeriod = source.hasScheduledTime ? source.endPeriod : 2
        weeks = Set(source.weekList)
    }

    init(weekday: Int, startPeriod: Int, endPeriod: Int, weeks: Set<Int>)
    {
        id = UUID()
        source = nil
        self.weekday = weekday
        self.startPeriod = startPeriod
        self.endPeriod = endPeriod
        self.weeks = weeks
    }

    var weeksText: String
    {
        guard !weeks.isEmpty else { return "未选择周次" }
        return weeks.sorted().map(String.init).joined(separator: ",") + "周"
    }
}
