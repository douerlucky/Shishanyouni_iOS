import Foundation

//
//  CurriculumModels.swift
//  shishanyouni
//
//  App 内课程模型、分组规则与接口数据转换。
//


// 课表接口模型位于 Curriculum/Models/CurriculumAPIModels.swift。

// MARK: - App 课程模型

enum CurriculumCourseType: String, Codable, CaseIterable, Identifiable
{
    case regular
    case other

    var id: Self { self }
    var title: String { self == .regular ? "普通课程" : "其他课程" }
}

/// App 内课表、桌面组件和系统日历共用的课程模型。
///
/// `Course` 是课程在本地存储中的稳定格式。新增可选字段时应保留默认值，
/// 从而让已保存的旧课表仍可解码。
struct Course: Identifiable, Codable
{
    let id: String
    /// 教务系统的完整课程名；用于分组、统计和数据匹配，不会被简称替换。
    let name: String
    /// 校园通行证用户可设置的显示简称；为空时一律回退到完整课程名。
    var shortName: String? = nil
    /// 周一为 1，周日为 7；无固定时段的其他课程使用 0，不虚构上课时间。
    let day: Int
    let start: Int
    let step: Int
    let room: String?
    let teacher: String?
    /// 实际上课周次；所有过滤判断都以它为准。
    let weekList: [Int]
    /// 仅用于展示的周次文本。
    let weeks: String?
    let term: String?
    var colorRandom: Int
    var customColorHex: String?
    var isManual: Bool
    /// 考试、考查或未安排；可选值保持对旧本地数据的兼容。
    var assessmentMethod: String? = nil
    /// 同时段冲突时，1 为用户手动指定优先显示；nil 与 0 都表示默认。
    var priority: Int? = nil
    var courseType: CurriculumCourseType = .regular

    var endPeriod: Int { start + step - 1 }
    var parsedWeeks: Set<Int> { Set(weekList) }
    var displayPriority: Int { priority ?? 0 }
    var hasScheduledTime: Bool
    {
        (1 ... 7).contains(day) && start > 0 && step > 0
    }

    private enum CodingKeys: String, CodingKey
    {
        case id, name, shortName, day, start, step, room, teacher, weekList, weeks, term
        case colorRandom, customColorHex, isManual, assessmentMethod, priority, courseType
    }

}

extension Course
{
    /// 旧课表没有课程类型字段，升级后仍按普通课程读取。
    init(from decoder: Decoder) throws
    {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        shortName = try values.decodeIfPresent(String.self, forKey: .shortName)
        courseType = try values.decodeIfPresent(CurriculumCourseType.self, forKey: .courseType) ?? .regular
        day = try values.decode(Int.self, forKey: .day)
        start = try values.decode(Int.self, forKey: .start)
        step = try values.decode(Int.self, forKey: .step)
        room = try values.decodeIfPresent(String.self, forKey: .room)
        teacher = try values.decodeIfPresent(String.self, forKey: .teacher)
        weekList = try values.decode([Int].self, forKey: .weekList)
        weeks = try values.decodeIfPresent(String.self, forKey: .weeks)
        term = try values.decodeIfPresent(String.self, forKey: .term)
        colorRandom = try values.decode(Int.self, forKey: .colorRandom)
        customColorHex = try values.decodeIfPresent(String.self, forKey: .customColorHex)
        isManual = try values.decode(Bool.self, forKey: .isManual)
        assessmentMethod = try values.decodeIfPresent(String.self, forKey: .assessmentMethod)
        priority = try values.decodeIfPresent(Int.self, forKey: .priority)
    }

    init(from model: TimetableModel)
    {
        // ID 包含时间和周次指纹，避免同名课程在不同时间相互覆盖。
        let sortedWeeks = model.weekList.sorted()
        let uniqueID = [model.term ?? "unknown", String(model.day), String(model.start), String(model.step),
                        sortedWeeks.map(String.init).joined(separator: ","), model.name, model.room ?? "", model.teacher ?? ""]
            .map { "\($0.utf8.count):\($0)" }.joined(separator: "|")

        let weeksText: String? = {
            if let weeks = model.weeks, !weeks.isEmpty { return weeks }
            if let time = model.time, !time.isEmpty { return time }
            guard !model.weekList.isEmpty else { return nil }
            return model.weekList.sorted().map(String.init).joined(separator: ",") + "周"
        }()

        self.init(
            id: uniqueID,
            name: model.name,
            day: model.day,
            start: model.start,
            step: model.step,
            room: model.room.flatMap { $0.isEmpty ? nil : $0 },
            teacher: model.teacher.flatMap { $0.isEmpty ? nil : $0 },
            weekList: model.weekList,
            weeks: weeksText,
            term: model.term,
            colorRandom: model.colorRandom,
            customColorHex: nil,
            isManual: false,
            assessmentMethod: model.assessmentMethod
        )
    }

    static func createManualCourse(
        name: String,
        weekday: Int,
        startPeriod: Int,
        endPeriod: Int,
        weeks: Set<Int>,
        location: String? = nil,
        teacher: String? = nil,
        customColorHex: String? = nil
    ) -> Course
    {
        let sortedWeeks = weeks.sorted()
        let weeksText = sortedWeeks.map(String.init).joined(separator: ",") + "周"

        return Course(
            id: "manual_\(UUID().uuidString)",
            name: name,
            day: weekday,
            start: startPeriod,
            step: endPeriod - startPeriod + 1,
            room: location,
            teacher: teacher,
            weekList: sortedWeeks,
            weeks: weeksText,
            term: nil,
            colorRandom: Int.random(in: 0 ... 31),
            customColorHex: customColorHex,
            isManual: true
        )
    }
}

enum CurriculumError: LocalizedError
{
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case jsonDecodingFailed(Error)

    var errorDescription: String?
    {
        switch self
        {
        case .invalidURL: return "接口地址无效"
        case .invalidResponse: return "无效的服务器响应"
        case let .httpError(code): return "HTTP 错误：\(code)"
        case let .apiError(message): return "服务端错误：\(message)"
        case let .jsonDecodingFailed(error): return "数据解析失败：\(error.localizedDescription)"
        }
    }
}

// MARK: - 所有课程页的展示分组

/// 同一门课的判断依据：类型、名称、教室、老师、学期。
/// 底层 Course 仍是一条时间段记录；这里只用于“所有课程”页面合并展示。
struct CourseGroupKey: Hashable
{
    let name: String
    let room: String
    let teacher: String
    let term: String
    let courseType: CurriculumCourseType

    init(course: Course)
    {
        name = Self.normalized(course.name)
        room = Self.normalized(course.room)
        teacher = Self.normalized(course.teacher)
        term = Self.normalized(course.term)
        courseType = course.courseType
    }

    private static func normalized(_ value: String?) -> String
    {
        (value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(
                of: "\\s+",
                with: " ",
                options: .regularExpression
            )
    }
}

/// “所有课程”列表中的一门课程，以及它包含的全部时间段。
struct CourseGroup: Identifiable
{
    let id: CourseGroupKey
    let name: String
    let room: String?
    let teacher: String?
    let courses: [Course]

    var courseType: CurriculumCourseType { id.courseType }

    var shortName: String?
    {
        courses.first?.shortName
    }

    /// 一门课程的各时间段共用考查形式；旧数据没有该字段时显示“未指定”。
    var assessmentMethod: String?
    {
        courses.compactMap(\.assessmentMethod)
            .first { $0 == "考查" || $0 == "考试" }
    }

    init(id: CourseGroupKey, courses: [Course])
    {
        precondition(!courses.isEmpty)

        let first = courses[0]
        self.id = id
        self.name = first.name
        self.room = first.room
        self.teacher = first.teacher

        // 同一课程组内按“星期 → 开始节次 → 周次”显示。
        self.courses = courses.sorted
        {
            if $0.day != $1.day { return $0.day < $1.day }
            if $0.start != $1.start { return $0.start < $1.start }
            return $0.weekList.lexicographicallyPrecedes($1.weekList)
        }
    }
}

extension Array where Element == Course
{
    /// 将扁平课表记录按课程身份组合，供“所有课程”页面展示。
    func groupedForCourseManagement() -> [CourseGroup]
    {
        let grouped = Dictionary(grouping: self)
        {
            CourseGroupKey(course: $0)
        }

        return grouped
            .map
            {
                CourseGroup(id: $0.key, courses: $0.value)
            }
            .sorted
            {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }
}
