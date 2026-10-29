import Foundation

/// 与一个红色格子绑定的课程详情；矩阵只负责布尔占用，详情单独保存以供用户核对地点。
struct CourseAvailabilitySlot: Identifiable
{
    let week: Int
    let weekday: Int
    let period: Int
    let entries: [CourseAvailabilityEntry]

    var id: String { "\(week)-\(weekday)-\(period)" }
}

/// 课表占用数据。
/// `occupied[week][weekday][period]` 等价于 C++ 的 `vector<vector<vector<bool>>>`：
/// 第一维是周数，第二维是星期（周一为 0），第三维是节次（第 1 节为 0）。
struct CourseAvailabilityData
{
    static let weekdayCount = 7
    static let periodCount = 12
    private static let minimumWeekCount = 20

    let occupied: [[[Bool]]]
    private let slotEntries: [[[[CourseAvailabilityEntry]]]]
    let weekRange: ClosedRange<Int>
    let unparsedCourseNames: [String]

    init(
        courses: [SelectedCourse],
        supplementarySchedules: [SelectedCourseScheduleEntry] = []
    )
    {
        var occurrences: [CourseAvailabilityOccurrence] = []
        var unparsedCourseNames = Set<String>()
        var seenSchedules = Set<String>()

        for course in courses
        {
            let schedules = course.availabilitySchedules.filter
            {
                seenSchedules.insert($0.id).inserted
            }
            let parsed = schedules.flatMap
            {
                CourseScheduleParser.occurrences(from: $0)
            }
            if parsed.isEmpty, !schedules.isEmpty
            {
                unparsedCourseNames.insert(course.courseName)
            }
            occurrences.append(contentsOf: parsed)
        }

        for schedule in supplementarySchedules where seenSchedules.insert(schedule.id).inserted
        {
            let parsed = CourseScheduleParser.occurrences(from: schedule)
            if parsed.isEmpty
            {
                unparsedCourseNames.insert(schedule.courseName)
            }
            occurrences.append(contentsOf: parsed)
        }

        let maximumWeek = max(
            Self.minimumWeekCount,
            occurrences.flatMap(\.weeks).max() ?? 1
        )
        let range = 1 ... maximumWeek
        weekRange = range

        var entries = Array(
            repeating: Array(
                repeating: Array(repeating: [CourseAvailabilityEntry](), count: Self.periodCount),
                count: Self.weekdayCount
            ),
            count: maximumWeek
        )

        for occurrence in occurrences
        {
            for week in occurrence.weeks where range.contains(week)
            {
                for weekday in occurrence.weekdays where (1 ... Self.weekdayCount).contains(weekday)
                {
                    for period in occurrence.periods where (1 ... Self.periodCount).contains(period)
                    {
                        let index = (week - 1, weekday - 1, period - 1)
                        if !entries[index.0][index.1][index.2].contains(occurrence.entry)
                        {
                            entries[index.0][index.1][index.2].append(occurrence.entry)
                        }
                    }
                }
            }
        }

        slotEntries = entries
        occupied = entries.map
        { week in
            week.map
            { weekday in
                weekday.map { !$0.isEmpty }
            }
        }
        self.unparsedCourseNames = unparsedCourseNames.sorted()
    }

    var initialWeek: Int { weekRange.lowerBound }

    var hasBusySlot: Bool
    {
        occupied.contains
        { week in
            week.contains
            { weekday in
                weekday.contains(true)
            }
        }
    }

    func entries(week: Int, weekday: Int, period: Int) -> [CourseAvailabilityEntry]
    {
        guard weekRange.contains(week),
              (1 ... Self.weekdayCount).contains(weekday),
              (1 ... Self.periodCount).contains(period)
        else { return [] }

        return slotEntries[week - 1][weekday - 1][period - 1]
    }
}

struct CourseAvailabilityOccurrence
{
    let weeks: [Int]
    let weekdays: [Int]
    let periods: [Int]
    let entry: CourseAvailabilityEntry
}

struct CourseAvailabilityEntry: Identifiable, Hashable
{
    let id: String
    let courseName: String
    let teachingClassName: String?
    let teacher: String?
    let timeText: String
    let location: String
}
