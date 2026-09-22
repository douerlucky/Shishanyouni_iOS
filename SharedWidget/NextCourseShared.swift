//
//  NextCourseShared.swift
//  shishanyouni
//
//  下节课 Widget 的跨 Target 数据模型与选择逻辑。
//

import Foundation

/// 主 App 写给下节课 Widget 的精简课程实例。
///
/// 课表中的 `Course` 只保存第几周、周几和第几节；这里已经还原为绝对时间，
/// 因此 Widget Extension 不必依赖主 App 的课程模型或节次计算逻辑。
struct WidgetNextCourse: Codable, Identifiable, Equatable
{
    let id: String
    let name: String
    let startDate: Date
    let endDate: Date
    let room: String?
    let teacher: String?
    let periodText: String
    /// 来自 App `Course.priority` 的展示优先级；nil 与 0 都表示未指定。
    let priority: Int?

    private enum CodingKeys: String, CodingKey
    {
        case id
        case name
        case startDate
        case endDate
        case room
        case teacher
        case periodText
        case priority
    }

    init(
        id: String,
        name: String,
        startDate: Date,
        endDate: Date,
        room: String?,
        teacher: String? = nil,
        periodText: String,
        priority: Int? = nil
    )
    {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.room = room
        self.teacher = teacher
        self.periodText = periodText
        self.priority = priority
    }

    /// 兼容升级前已经写入 App Group 的课程数据。
    /// 旧版本没有 `teacher` 字段，缺失时按“暂无教师信息”处理，而不是让整份数据解码失败。
    init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        room = try container.decodeIfPresent(String.self, forKey: .room)
        teacher = try container.decodeIfPresent(String.self, forKey: .teacher)
        periodText = try container.decode(String.self, forKey: .periodText)
        // 旧版本的 App Group 数据没有 priority，缺失时按未指定处理。
        priority = try container.decodeIfPresent(Int.self, forKey: .priority)
    }

    /// 旧数据中的 nil 与新数据中的 0 语义完全相同：都没有手动优先级。
    var displayPriority: Int { priority ?? 0 }
}

/// 下节课 Widget 的 App Group 存储和展示选择逻辑。
///
/// 该类型只使用 Foundation，主 App 和 Widget Extension 可复用；
/// 调用 `WidgetCenter.reloadTimelines` 的动作留在 App 侧 `NextCourseSync`。
enum NextCourseWidgetShared
{
    /// “近 2 天”按当前时刻起的 48 小时计算。
    static let displayWindow: TimeInterval = 2 * 24 * 60 * 60

    static func save(_ courses: [WidgetNextCourse])
    {
        guard let data = try? JSONEncoder().encode(courses) else { return }
        WidgetAppGroup.defaults?.set(data, forKey: WidgetAppGroup.Key.nextCourseItems)
    }

    static func load() -> [WidgetNextCourse]?
    {
        guard let data = WidgetAppGroup.defaults?.data(forKey: WidgetAppGroup.Key.nextCourseItems) else
        {
            return nil
        }
        return try? JSONDecoder().decode([WidgetNextCourse].self, from: data)
    }

    static func clear()
    {
        WidgetAppGroup.defaults?.removeObject(forKey: WidgetAppGroup.Key.nextCourseItems)
    }

    /// 返回当前正在上课的课程；若没有，再返回未来 48 小时内最早开始的课程。
    ///
    /// 因此组件会在课程开始时由“下节课”切到“正在上课”，并以该课结束时间
    /// 作为下一次状态切换点。
    static func currentOrNextCourse(at date: Date = .now) -> WidgetNextCourse?
    {
        if let currentCourse = load()?
            .filter({ $0.startDate <= date && date < $0.endDate })
            .min(by: currentCourseComesBefore)
        {
            return currentCourse
        }

        let windowEnd = date.addingTimeInterval(displayWindow)
        return load()?
            .filter { $0.startDate > date && $0.startDate <= windowEnd }
            .min
            {
                if $0.startDate != $1.startDate { return $0.startDate < $1.startDate }
                if $0.displayPriority != $1.displayPriority
                {
                    return $0.displayPriority > $1.displayPriority
                }
                return $0.id < $1.id
            }
    }

    /// 返回从当前时刻起、未来两天内将要上的课程，供桌面中号组件显示三节。
    ///
    /// “正在上课”的课程属于小号／锁屏的当前状态，不占用这里的三个未来名额。
    /// 同时段的课程先按 priority 决出唯一项，保证中号与课表卡片展示一致。
    static func upcomingCourses(at date: Date = .now) -> [WidgetNextCourse]
    {
        let windowEnd = date.addingTimeInterval(displayWindow)
        let candidates = (load() ?? [])
            .filter
            {
                $0.startDate > date && $0.startDate <= windowEnd
            }

        return resolveOverlappingCourses(candidates)
            .sorted
            {
                if $0.startDate != $1.startDate { return $0.startDate < $1.startDate }
                if $0.displayPriority != $1.displayPriority
                {
                    return $0.displayPriority > $1.displayPriority
                }
                return $0.id < $1.id
            }
    }

    /// 下一次值得请求系统刷新时间线的时刻。
    ///
    /// - 正在上课：在下课时刷新，以便改显示下一门课。
    /// - 尚未开始的下节课：在上课时刷新，以便改显示“正在上课”。
    /// - 近 2 天无课、但之后有课：在该课进入 48 小时窗口时刷新。
    /// - 没有候选数据：最晚次日再检查一次，避免永久停在空状态。
    static func nextRefreshDate(after date: Date = .now) -> Date
    {
        if let course = currentOrNextCourse(at: date)
        {
            return course.startDate <= date ? course.endDate : course.startDate
        }

        let windowEnd = date.addingTimeInterval(displayWindow)
        if let followingCourse = load()?
            .filter({ $0.startDate > windowEnd })
            .min(by: { $0.startDate < $1.startDate })
        {
            return followingCourse.startDate.addingTimeInterval(-displayWindow)
        }

        let tomorrow = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: Calendar.current.startOfDay(for: date)
        )
        return tomorrow ?? date.addingTimeInterval(24 * 60 * 60)
    }

    /// WidgetKit 不是常驻计时器；在 24 小时内用约 5 分钟粒度刷新倒计时文字。
    /// 课程开始和结束仍由 `nextRefreshDate` 精确作为时间线切换点。
    static func nextCountdownRefreshDate(after date: Date = .now) -> Date?
    {
        guard let course = currentOrNextCourse(at: date) else { return nil }
        let targetDate = course.startDate <= date ? course.endDate : course.startDate
        guard targetDate.timeIntervalSince(date) <= 24 * 60 * 60 else { return nil }

        let interval: TimeInterval = 5 * 60
        let rounded = (floor(date.timeIntervalSince1970 / interval) + 1) * interval
        let nextTick = Date(timeIntervalSince1970: rounded)
        return min(nextTick, targetDate)
    }

    private static func currentCourseComesBefore(_ lhs: WidgetNextCourse, _ rhs: WidgetNextCourse) -> Bool
    {
        // 用户明确选中的课程先显示；未选择时保留原有“更早下课优先”的结果。
        if lhs.displayPriority != rhs.displayPriority
        {
            return lhs.displayPriority > rhs.displayPriority
        }
        if lhs.endDate != rhs.endDate { return lhs.endDate < rhs.endDate }
        return lhs.id < rhs.id
    }

    private static func resolveOverlappingCourses(_ courses: [WidgetNextCourse]) -> [WidgetNextCourse]
    {
        guard courses.count > 1 else { return courses }
        let sorted = courses.sorted { $0.startDate < $1.startDate }
        var parent = Array(0 ..< sorted.count)

        func find(_ index: Int) -> Int
        {
            var index = index
            while parent[index] != index { index = parent[index] }
            return index
        }

        func union(_ lhs: Int, _ rhs: Int)
        {
            parent[find(lhs)] = find(rhs)
        }

        for lhs in 0 ..< sorted.count
        {
            for rhs in (lhs + 1) ..< sorted.count
            {
                if sorted[lhs].startDate < sorted[rhs].endDate,
                   sorted[rhs].startDate < sorted[lhs].endDate
                {
                    union(lhs, rhs)
                }
            }
        }

        var groups: [Int: [WidgetNextCourse]] = [:]
        for (index, course) in sorted.enumerated()
        {
            groups[find(index), default: []].append(course)
        }

        return groups.values.map
        {
            $0.reduce($0[0])
            { currentWinner, candidate in
                if currentWinner.displayPriority != candidate.displayPriority
                {
                    return currentWinner.displayPriority > candidate.displayPriority
                        ? currentWinner
                        : candidate
                }
                if currentWinner.endDate != candidate.endDate
                {
                    return currentWinner.endDate <= candidate.endDate ? currentWinner : candidate
                }
                return currentWinner.id <= candidate.id ? currentWinner : candidate
            }
        }
    }
}
