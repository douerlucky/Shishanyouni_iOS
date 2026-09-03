//
//  SearchCourse.swift
//  shishanyouni
//
//  课程检索与子教学班读取。这里的所有请求都是只读请求；最终选课/退选写操作在
//  CourseEdit.swift 中完成，避免查询代码意外触发教务系统状态变更。
//

import Foundation
import SwiftUI

/// 搜索结果中的一个主教学班。
///
/// `selectionToken` 和 `context` 都是本次教务会话签发的临时参数，只在内存中流转，
/// 既不显示在 UI，也不写入本地存储或日志。
struct CourseSearchResult: Identifiable
{
    /// 课程目录按教学班逐行返回，但首层 UI 会把同一门课合并成一张卡片。
    /// 展开接口有时只给 `jxb_id` 和临时 token，因此需要保留目录中每一行的展示资料，
    /// 再按教学班 ID 回填，不能把同课程第一行的内容复制给其它教学班。
    struct CatalogTeachingClass: Hashable
    {
        let teachingClassID: String
        let teachingClassName: String
        let credit: String
        let classLevels: Int
        let teachingClassComposition: String
        let teacherInfo: String
        let classTime: String
        let location: String
        let courseMaterial: String
        let selectionRemark: String
        let courseNature: String
        let teachingMode: String
        let selectedCount: String
        let capacity: String
    }

    let id = UUID()
    let courseCode: String
    let courseID: String
    let courseName: String
    let teachingClassName: String
    let credit: String
    let classLevels: Int
    let teachingClassID: String
    let selectionToken: String
    let context: CourseSelectionContext
    let selectionCaption: String

    /// `PartDisplay` 的摘要和展开后的 `cxJxbWithKch` 详情字段并不完全相同。
    /// 先完整保留服务端能给出的信息，展开教学班时再用详情响应补齐，避免在 UI 层猜字段。
    let teachingClassComposition: String
    let teacherInfo: String
    let classTime: String
    let location: String
    let courseMaterial: String
    let selectionRemark: String
    let courseNature: String
    let teachingMode: String
    let selectedCount: String
    let capacity: String
    /// 目录会按课程号合并成一张卡片；这个值只用于提示教学班数量，不参与任何选课请求。
    let catalogTeachingClassCount: Int
    /// 仅保存同一次目录响应的展示快照；不保存教学班临时 token，也不会跨登录会话复用。
    let catalogTeachingClasses: [CatalogTeachingClass]

    init(
        courseCode: String,
        courseID: String,
        courseName: String,
        teachingClassName: String,
        credit: String,
        classLevels: Int,
        teachingClassID: String,
        selectionToken: String,
        context: CourseSelectionContext,
        selectionCaption: String,
        teachingClassComposition: String = "",
        teacherInfo: String = "",
        classTime: String = "",
        location: String = "",
        courseMaterial: String = "",
        selectionRemark: String = "",
        courseNature: String = "",
        teachingMode: String = "",
        selectedCount: String = "",
        capacity: String = "",
        catalogTeachingClassCount: Int = 1,
        catalogTeachingClasses: [CatalogTeachingClass] = []
    )
    {
        self.courseCode = courseCode
        self.courseID = courseID
        self.courseName = courseName
        self.teachingClassName = teachingClassName
        self.credit = credit
        self.classLevels = classLevels
        self.teachingClassID = teachingClassID
        self.selectionToken = selectionToken
        self.context = context
        self.selectionCaption = selectionCaption
        self.teachingClassComposition = teachingClassComposition
        self.teacherInfo = teacherInfo
        self.classTime = classTime
        self.location = location
        self.courseMaterial = courseMaterial
        self.selectionRemark = selectionRemark
        self.courseNature = courseNature
        self.teachingMode = teachingMode
        self.selectedCount = selectedCount
        self.capacity = capacity
        self.catalogTeachingClassCount = catalogTeachingClassCount
        self.catalogTeachingClasses = catalogTeachingClasses
    }

    /// 正方用 jxbzls 表示教学班层级；大于 1 时必须让用户继续选择叶子教学班。
    var requiresChildClass: Bool { classLevels > 1 }
    var hasCurrentSelectionParameters: Bool
    {
        !courseID.isEmpty && !teachingClassID.isEmpty && !selectionToken.isEmpty
    }

    var displayTitle: String
    {
        courseCode.isEmpty ? courseName : "\(courseName)（\(courseCode)）"
    }

    var enrollmentText: String
    {
        capacityStatus.displayText
    }

    /// 人数数据由详情接口动态返回。`jxbrs` 是已选人数，`jxbrl` 是教学班容量；
    /// 这里集中计算余量档位，避免主卡、子班 Sheet 和按钮各自使用不同的阈值。
    var capacityStatus: CourseCapacityStatus
    {
        CourseCapacityStatus(selectedCount: selectedCount, capacity: capacity)
    }

    var teachingClassCountText: String
    {
        "\(max(catalogTeachingClassCount, 1)) 个教学班"
    }

    /// 同一目录加载周期内，课程号足以唯一定位一张首层课程卡片。
    /// 缓存会在刷新/切换类别时清空，因此这里不保存跨会话的教学班 token。
    var catalogKey: String
    {
        courseID.ifEmpty(courseCode).ifEmpty(courseName)
    }

    /// 将同一课程的多条目录摘要合并为一张可展开的课程卡片。
    /// 真正可选的教学班仍在用户展开后，从当前会话重新读取，不能复用旧摘要里的参数。
    func catalogSummary(
        teachingClassCount: Int,
        catalogTeachingClasses: [CatalogTeachingClass]
    ) -> CourseSearchResult
    {
        CourseSearchResult(
            courseCode: courseCode,
            courseID: courseID,
            courseName: courseName,
            teachingClassName: teachingClassName,
            credit: credit,
            classLevels: classLevels,
            teachingClassID: teachingClassID,
            selectionToken: selectionToken,
            context: context,
            selectionCaption: selectionCaption,
            teachingClassComposition: teachingClassComposition,
            teacherInfo: teacherInfo,
            classTime: classTime,
            location: location,
            courseMaterial: courseMaterial,
            selectionRemark: selectionRemark,
            courseNature: courseNature,
            teachingMode: teachingMode,
            selectedCount: selectedCount,
            capacity: capacity,
            catalogTeachingClassCount: teachingClassCount,
            catalogTeachingClasses: catalogTeachingClasses
        )
    }
}

/// 教学班余量的统一展示规则。
///
/// 颜色只用于“能否选到”的即时提示，卡片本身始终维持系统灰色层级，避免整页被高饱和色占满。
struct CourseCapacityStatus
{
    let selected: Int?
    let capacity: Int?

    init(selectedCount: String, capacity: String)
    {
        selected = Self.number(from: selectedCount)
        self.capacity = Self.number(from: capacity)
    }

    var hasCompleteCounts: Bool
    {
        guard let selected, let capacity else { return false }
        return selected >= 0 && capacity > 0
    }

    var isFull: Bool
    {
        guard let selected, let capacity, capacity > 0 else { return false }
        return selected >= capacity
    }

    /// 剩余比例按容量向下计算：满班红色，≤5% 橙色，≤20% 黄色，≤50% 蓝色，其余绿色。
    var tint: Color
    {
        guard hasCompleteCounts, let selected, let capacity else { return .gray }
        if selected >= capacity { return .red }

        let remainingRatio = Double(max(capacity - selected, 0)) / Double(capacity)
        if remainingRatio <= 0.05 { return .orange }
        if remainingRatio <= 0.20 { return .yellow }
        if remainingRatio <= 0.50 { return .blue }
        return .green
    }

    /// 黄色按钮使用深色字，其他语义色使用白字，保证在浅色模式和深色模式下都可读。
    var buttonForeground: Color
    {
        guard hasCompleteCounts, let selected, let capacity, selected < capacity else { return .white }
        let remainingRatio = Double(capacity - selected) / Double(capacity)
        return remainingRatio > 0.05 && remainingRatio <= 0.20 ? .black : .white
    }

    var displayText: String
    {
        if let selected, let capacity, capacity > 0
        {
            return "\(selected)/\(capacity)\(selected >= capacity ? " 已满" : "")"
        }
        if let selected { return "已选 \(selected)" }
        if let capacity { return "容量 \(capacity)" }
        return "人数待教务返回"
    }

    var availabilityText: String
    {
        hasCompleteCounts ? "已选/容量 \(displayText)" : displayText
    }

    private static func number(from rawValue: String) -> Int?
    {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let number = Int(value) { return number }
        if let number = Double(value), number.rounded() == number { return Int(number) }
        return nil
    }
}

/// 选课主页最上方的五个课程类别。
///
/// 除选课规则本身以外的学院、专业、年级等参数，均从本次选课页动态读取；不能把抓包中
/// 某位同学的个人字段写死。`xkkz_id` 则是学校当前选课方案中对应类别的规则 ID，必须和
/// 浏览器该类别实际发送的值一致，才可让教务系统返回正确的课程目录。
enum CourseCatalogCategory: String, CaseIterable, Identifiable
{
    case major
    case generalEducation
    case mooc
    case physicalEducation
    case english

    var id: String { rawValue }

    var title: String
    {
        switch self
        {
        case .major: return "主修课程"
        case .generalEducation: return "通识选修课"
        case .mooc: return "MOOC"
        case .physicalEducation: return "体育"
        case .english: return "英语"
        }
    }

    var shortTitle: String
    {
        switch self
        {
        case .major: return "主修"
        case .generalEducation: return "通识"
        case .mooc: return "MOOC"
        case .physicalEducation: return "体育"
        case .english: return "英语"
        }
    }

    /// 服务端页签名称并非账号数据；仅用于把页面实际返回的规则映射到 App 的五个分段。
    /// 规则 ID、开课类型、任务类型等提交参数都不会在这里写死。
    func matchesServerTitle(_ rawTitle: String) -> Bool
    {
        let title = rawTitle
            .replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
            .uppercased()
        switch self
        {
        case .major:
            return title.contains("主修") || title.contains("培养计划")
        case .generalEducation:
            return title.contains("通识") && !title.contains("MOOC")
        case .mooc:
            return title.contains("MOOC")
        case .physicalEducation:
            return title.contains("体育")
        case .english:
            return title.contains("英语")
        }
    }
}

/// 从当前账号的选课页解析出的一个真实页签规则。
/// 这两个值由网页 `queryCourse(...)` 直接提供，只在本次页面加载期间保留在内存。
struct CourseCatalogRule: Equatable
{
    let category: CourseCatalogCategory
    let courseTypeCode: String
    let controlID: String
}

/// 一次课程目录区间请求的结果。
/// 正方的 `kspage` / `jspage` 实际表示结果区间，例如 1–10 后接 11–20，
/// 不是传统意义上的“第 N 页”。
struct CourseCatalogPage
{
    let courses: [CourseSearchResult]
    let hasMore: Bool
    let nextRangeStart: Int
    /// 由当前账号的选课 Index / Display 页面返回；设备日期只在页面缺字段时才兜底。
    let semester: SelectedCourseSemester
    /// 学年、学期、轮次、学分规则和截止时间全部来自本次页面，不来自本地日期推测。
    let overview: CourseSelectionOverview
}

/// 多层课程里由用户明确选择的子教学班。
struct CourseChildClass: Identifiable
{
    let id = UUID()
    let name: String
    let teacher: String
    let schedule: String
    let location: String
    let selectedCount: String
    let capacity: String
    let selectionTokens: [String]

    var canSelect: Bool { !selectionTokens.isEmpty }
    var capacityStatus: CourseCapacityStatus
    {
        CourseCapacityStatus(selectedCount: selectedCount, capacity: capacity)
    }
}

/// 正方选课页里的隐藏字段与初始化脚本值。
/// 这些值必须来自当前页面，不能由课程号、专业名称或历史抓包推导。
struct CourseSelectionContext
{
    var values: [String: String]

    static let responseFields = [
        "rwlx", "sfkccxk", "xkly", "bklx_id", "xqh_id", "jg_id", "jg_id_1",
        "rlkz", "rlzlkz", "sxbj", "xxkbj", "cxbj", "kklxdm", "xkkz_id",
        "firstKklxdm", "firstXkkzId", "njdm_id", "zyh_id", "zyfx_id", "bh_id",
        "xh_id", "xbm", "xslbdm", "ccdm", "xsbj", "sfkknj", "sfkkzy", "sfznkx",
        "zdkxms", "sfkxq", "sfkcfx", "kkbk", "kkbkdj", "sfkgbcx", "sfctxk",
        "sfrxtgkcxd", "tykczgxdcs", "xklc", "xkxnm", "xkxqm", "qz", "fxbj",
        "txbsfrl", "syqz", "jxbzbkg", "jxbzb", "jxbzhkg", "zh", "iskxk",
        "xszxzt", "s_njdm_id", "s_zyh_id", "t_njdm_id", "t_zyh_id",
        // 下面是展示用元数据。它们不参与选/退课写请求，只从当前 Index / Display 页面读取。
        "xklcmc", "xkxnmc", "xkxqmc", "yxxfs", "selectionMinimumCredit",
        "selectionMaximumCredit", "earnedCredit", "selectionCountdownText", "syts", "syxs", "xkjssj",
        "xk_jssj", "jssj", "jzsj", "endTime", "end_time", "endDate", "sysj"
    ]

    static let catalogFields = [
        "rwlx", "sfkccxk", "xkly", "bklx_id", "xqh_id", "jg_id", "zyh_id",
        "zyfx_id", "njdm_id", "bh_id", "xbm", "xslbdm", "ccdm", "xsbj",
        "sfkknj", "sfkkzy", "sfznkx", "zdkxms", "sfkxq", "sfkcfx", "kkbk",
        "kkbkdj", "sfkgbcx", "sfctxk", "sfrxtgkcxd", "tykczgxdcs", "xkxnm",
        "xkxqm", "kklxdm", "rlkz", "xkkz_id"
    ]

    static let parentClassFields = [
        "rwlx", "sfkccxk", "xkly", "bklx_id", "xqh_id", "jg_id", "zyh_id",
        "zyfx_id", "njdm_id", "bh_id", "xbm", "xslbdm", "ccdm", "xsbj",
        "sfkknj", "sfkkzy", "sfznkx", "zdkxms", "sfkxq", "sfkcfx", "kkbk",
        "kkbkdj", "xkxnm", "xkxqm", "rlkz", "kklxdm", "xkkz_id", "cxbj", "fxbj"
    ]

    static let childDisplayFields = [
        "xkxnm", "xkxqm", "xkly", "rlkz", "rlzlkz", "rwlx", "syqz", "zyfx_id",
        "bh_id", "zyh_id", "njdm_id", "sfkknj", "sfkkzy", "sfznkx", "kklxdm",
        "xh_id", "bklx_id", "kkbk", "kkbkdj", "fxbj", "cxbj"
    ]

    /// 最终 xkBc 写请求要求的字段。缺任意字段时宁可停止，也不拼凑请求。
    static let selectionRequiredFields = [
        "rwlx", "rlkz", "rlzlkz", "sxbj", "xxkbj", "cxbj", "kklxdm", "xkkz_id",
        "njdm_id", "zyh_id", "xklc", "xkxnm", "xkxqm", "qz"
    ]

    init(values: [String: String] = [:])
    {
        self.values = values
    }

    func value(_ name: String) -> String
    {
        values[name] ?? ""
    }

    func merged(with newer: CourseSelectionContext) -> CourseSelectionContext
    {
        var merged = values
        for (rawKey, rawValue) in newer.values
        {
            let key = rawKey == "jg_id_1" ? "jg_id" : rawKey
            let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            // Display 片段会渲染许多空 input；空值不能覆盖 Index 壳页里已有的有效上下文。
            if merged[key] == nil || !value.isEmpty
            {
                merged[key] = value
            }
        }

        if merged["kklxdm"].isEmptyOrNil, let first = merged["firstKklxdm"], !first.isEmpty
        {
            merged["kklxdm"] = first
        }
        if merged["xkkz_id"].isEmptyOrNil, let first = merged["firstXkkzId"], !first.isEmpty
        {
            merged["xkkz_id"] = first
        }

        return CourseSelectionContext(values: merged).applyingFrontendRuleValues()
    }

    /// 严格复现 `zzxkYzbZy.js`：切换页签后，网页会依据该页签的 rwlx / kklxdm，
    /// 重新把学生或培养方案的年级、专业写入真正提交字段。不能只在字段为空时补值，
    /// 否则切换到不同类型的课程仍会带着上一个页签的专业上下文。
    func applyingFrontendRuleValues() -> CourseSelectionContext
    {
        var updated = values
        let useStudentContext = updated["rwlx"] == "1"
            && !["01", "30"].contains(updated["kklxdm"] ?? "")
        let gradeSource = useStudentContext ? "s_njdm_id" : "t_njdm_id"
        let majorSource = useStudentContext ? "s_zyh_id" : "t_zyh_id"
        if let grade = updated[gradeSource], !grade.isEmpty
        {
            updated["njdm_id"] = grade
        }
        if let major = updated[majorSource], !major.isEmpty
        {
            updated["zyh_id"] = major
        }
        return CourseSelectionContext(values: updated)
    }

    /// `queryCourse(...)` 切换页签时只改变这两个值，随后由 Display 接口返回该规则的
    /// 其它开关。它们全部来自当前账号的 Index 页面，不能使用历史抓包中的 ID。
    func applying(_ rule: CourseCatalogRule) -> CourseSelectionContext
    {
        var updated = values
        updated["kklxdm"] = rule.courseTypeCode
        updated["xkkz_id"] = rule.controlID
        return CourseSelectionContext(values: updated)
    }

    /// 页面明确返回的学年 / 学期优先。传入值只是旧模板漏字段时的安全兜底，
    /// 绝不能用设备日期把不同账号当前实际开放的选课学期覆盖掉。
    func applying(_ semester: SelectedCourseSemester) -> CourseSelectionContext
    {
        var updated = values
        if updated["xkxnm"].isEmptyOrNil
        {
            updated["xkxnm"] = semester.academicYear
        }
        if updated["xkxqm"].isEmptyOrNil
        {
            updated["xkxqm"] = semester.termCode
        }
        return CourseSelectionContext(values: updated)
    }

    /// 从本次教务页面得到真正要提交的学年、学期代码；缺失时才回退到调用方的日期推测。
    func resolvedSemester(fallback: SelectedCourseSemester) -> SelectedCourseSemester
    {
        let academicYear = value("xkxnm").trimmingCharacters(in: .whitespacesAndNewlines)
        let termCode = value("xkxqm").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !academicYear.isEmpty, !termCode.isEmpty else { return fallback }
        return SelectedCourseSemester(academicYear: academicYear, termCode: termCode)
    }

    var overview: CourseSelectionOverview
    {
        CourseSelectionOverview(context: self)
    }
}

/// 选课页顶部展示信息。
///
/// 这里刻意区分“接口提交代码”（`xkxnm` / `xkxqm`）和“网页展示名称”（`xkxnmc` /
/// `xkxqmc`）：前者用于协议，后者才是给用户看的学年、学期和轮次。
struct CourseSelectionOverview: Equatable
{
    var academicYearName: String
    var termName: String
    var roundName: String
    var minimumCredit: Double?
    var maximumCredit: Double?
    var earnedCredit: Double?
    var selectedCredit: Double?
    /// `syts` / `syxs` 是选课 Display 页面直接给出的剩余天数 / 小时数。
    /// 它们比从页面里猜截止时间可靠，且正是网页 i18n 文案填入 `{0}` 的数据源。
    var remainingDays: Int?
    var remainingHours: Int?
    var selectionEndDate: Date?
    var serverCountdownText: String

    init(context: CourseSelectionContext)
    {
        let rawYear = context.value("xkxnmc").trimmingCharacters(in: .whitespacesAndNewlines)
        let rawTerm = context.value("xkxqmc").trimmingCharacters(in: .whitespacesAndNewlines)
        let rawRound = context.value("xklcmc").trimmingCharacters(in: .whitespacesAndNewlines)
        academicYearName = rawYear.ifEmpty(Self.academicYearName(from: context.value("xkxnm")))
        termName = Self.termDisplayName(rawTerm.ifEmpty(context.value("xkxqm")))
        roundName = rawRound.ifEmpty(Self.roundDisplayName(context.value("xklc")))
        minimumCredit = Self.creditValue(context.value("selectionMinimumCredit"))
        maximumCredit = Self.creditValue(context.value("selectionMaximumCredit"))
        earnedCredit = Self.creditValue(context.value("earnedCredit"))
        selectedCredit = Self.creditValue(context.value("yxxfs"))
        remainingDays = Self.nonNegativeWholeNumber(context.value("syts"))
        remainingHours = Self.nonNegativeWholeNumber(context.value("syxs"))
        serverCountdownText = context.value("selectionCountdownText")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        selectionEndDate = Self.selectionEndDate(from: context)
    }

    static let empty = CourseSelectionOverview(context: CourseSelectionContext())

    var selectionTitle: String
    {
        [
            academicYearName.isEmpty ? nil : "\(academicYearName) 学年",
            termName.isEmpty ? nil : termName,
            roundName.isEmpty ? nil : roundName
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }

    var selectedCreditText: String
    {
        Self.creditText(selectedCredit)
    }

    var earnedCreditText: String
    {
        Self.creditText(earnedCredit)
    }

    var creditRangeText: String
    {
        switch (minimumCredit, maximumCredit)
        {
        case let (minimum?, maximum?): return "\(Self.creditText(minimum))–\(Self.creditText(maximum)) 学分"
        case let (minimum?, nil): return "最低 \(Self.creditText(minimum)) 学分"
        case let (nil, maximum?): return "最高 \(Self.creditText(maximum)) 学分"
        case (nil, nil): return "教务暂未返回要求"
        }
    }

    /// 截止时间来自网页时，按 i18n 文件的“剩余天 / 小时”口径实时换算；
    /// 如果学校改成只渲染文字，也保留服务器给出的倒计时，不伪造一个本地截止时间。
    func countdownText(at date: Date = Date()) -> String?
    {
        // 教务 Display 页返回 syts=0、syxs>0 时，网页会切换为“剩余 X 小时”；
        // 所以必须先判断天数是否大于零，再回退到小时。
        if let remainingDays, remainingDays > 0
        {
            return "距选课结束还剩\(remainingDays)天"
        }
        if let remainingHours, remainingHours > 0
        {
            return "距选课结束还剩\(remainingHours)小时"
        }
        if let selectionEndDate
        {
            let remaining = selectionEndDate.timeIntervalSince(date)
            guard remaining > 0 else { return "本轮选课已结束" }
            if remaining >= 86_400
            {
                return "距选课结束还剩\(Int(ceil(remaining / 86_400)))天"
            }
            return "距选课结束还剩\(max(1, Int(ceil(remaining / 3_600))))小时"
        }
        return serverCountdownText.isEmpty ? nil : serverCountdownText
    }

    func replacingSelectedCredit(with credit: Double) -> CourseSelectionOverview
    {
        var copy = self
        copy.selectedCredit = credit
        return copy
    }

    private static func academicYearName(from year: String) -> String
    {
        guard let startYear = Int(year.trimmingCharacters(in: .whitespacesAndNewlines)) else { return "" }
        return "\(startYear)-\(startYear + 1)"
    }

    private static func termDisplayName(_ rawValue: String) -> String
    {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.contains("学期") { return value }
        switch value
        {
        case "1", "3": return "第一学期"
        case "2", "12": return "第二学期"
        default: return value.isEmpty ? "" : "第\(value)学期"
        }
    }

    private static func roundDisplayName(_ rawValue: String) -> String
    {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return "" }
        return value.contains("轮") ? value : "第\(value)轮"
    }

    private static func creditValue(_ rawValue: String) -> Double?
    {
        let normalized = rawValue
            .replacingOccurrences(of: "，", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(normalized)
    }

    private static func nonNegativeWholeNumber(_ rawValue: String) -> Int?
    {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let number = Int(value), number >= 0 { return number }
        if let number = Double(value), number >= 0, number.rounded() == number
        {
            return Int(number)
        }
        return nil
    }

    private static func creditText(_ value: Double?) -> String
    {
        guard let value else { return "--" }
        return value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }

    private static func selectionEndDate(from context: CourseSelectionContext) -> Date?
    {
        let candidateFields = ["xkjssj", "xk_jssj", "jssj", "jzsj", "endTime", "end_time", "endDate", "sysj"]
        for field in candidateFields
        {
            if let date = dateValue(context.value(field)) { return date }
        }
        return nil
    }

    private static func dateValue(_ rawValue: String) -> Date?
    {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if let timestamp = Double(value)
        {
            // JS 页面常用毫秒时间戳；十位数则按秒解释。
            return Date(timeIntervalSince1970: timestamp > 100_000_000_000 ? timestamp / 1_000 : timestamp)
        }

        let normalized = value
            .replacingOccurrences(of: "年", with: "-")
            .replacingOccurrences(of: "月", with: "-")
            .replacingOccurrences(of: "日", with: "")
            .replacingOccurrences(of: "/", with: "-")
        let formats = ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd"]
        for format in formats
        {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.timeZone = .current
            formatter.dateFormat = format
            if let date = formatter.date(from: normalized) { return date }
        }
        return nil
    }
}

private extension Optional where Wrapped == String
{
    var isEmptyOrNil: Bool { self?.isEmpty ?? true }
}

enum CourseSelectionServiceError: LocalizedError
{
    case invalidURL
    case invalidResponse(String)
    case sessionExpired
    case serverError(operation: String, statusCode: Int)
    case selectionClosed
    case noSearchResult
    case noChildClass
    case missingCurrentParameters
    case missingCategoryRule(String)
    case missingContext([String])

    var errorDescription: String?
    {
        switch self
        {
        case .invalidURL:
            return "选课服务地址无效。"
        case let .invalidResponse(operation):
            return "\(operation)返回的数据无法识别，教务系统页面可能已更新。"
        case .sessionExpired:
            return "教务登录状态已失效，请重新登录后再试。"
        case let .serverError(operation, statusCode):
            return "\(operation)失败（状态码 \(statusCode)）。"
        case .selectionClosed:
            return "教务系统当前未开放选课。"
        case .noSearchResult:
            return "没有找到可选的匹配课程，请确认课程号或名称后重试。"
        case .noChildClass:
            return "该课程没有返回可选择的子教学班，本次没有提交选课请求。"
        case .missingCurrentParameters:
            return "教务系统没有返回本次会话可用的教学班参数，已停止提交。请刷新后重新搜索。"
        case let .missingCategoryRule(category):
            return "没有从当前账号的选课页读取到“\(category)”的规则，已停止请求。请以教务系统页面为准。"
        case let .missingContext(fields):
            return "选课页缺少必要上下文（\(fields.joined(separator: "、"))），已停止提交。"
        }
    }
}

enum CourseSelectionEndpoint
{
    static let origin = "http://byjxyt.hzau.edu.cn"
    static let index = "http://byjxyt.hzau.edu.cn/xsxk/zzxkyzb_cxZzxkYzbIndex.html?gnmkdm=N253512&layout=default"
    static let display = "http://byjxyt.hzau.edu.cn/xsxk/zzxkyzb_cxZzxkYzbDisplay.html"
    static let catalog = "http://byjxyt.hzau.edu.cn/xsxk/zzxkyzb_cxZzxkYzbPartDisplay.html?gnmkdm=N253512"
    static let parentClass = "http://byjxyt.hzau.edu.cn/xsxk/zzxkyzb_cxJxbWithKchZzxkYzb.html?gnmkdm=N253512"
    static let childDialog = "http://byjxyt.hzau.edu.cn/xsxk/zzxkyzb_xkZyZzxkYzbZjxb.html?gnmkdm=N253512"
    static let childDisplay = "http://byjxyt.hzau.edu.cn/xsxk/zzxkyzb_xkZyDisplayZzxkYzbZjxb.html?gnmkdm=N253512"
    static let select = "http://byjxyt.hzau.edu.cn/xsxk/zzxkyzb_xkBcZyZzxkYzb.html?gnmkdm=N253512"
    static let dropCheck = "http://byjxyt.hzau.edu.cn/xsxk/zzxkyzb_xkJcInXksjZzxkYzb.html?gnmkdm=N253512"
    static let drop = "http://byjxyt.hzau.edu.cn/xsxk/zzxkyzb_tuikBcZzxkYzb.html?gnmkdm=N253512"
    static let preferenceSync = "http://byjxyt.hzau.edu.cn/xsxk/zzxkyzb_xkBcZypxZzxkYzb.html?gnmkdm=N253512"
    /// 已选主教学班对应的实验 / 子教学班明细。请求参数由当前账号的已选课程与
    /// 选课页面上下文动态组成，不能缓存其它账号的 jxb_ids。
    static let selectedClassSchedules = "http://byjxyt.hzau.edu.cn/xsxk/zzxkyzb_cxZkcZzxkYzb.html?gnmkdm=N253512"
}

/// 统一处理教务请求头、表单编码和会话失效检查。
/// 写请求调用时会传 `retryCount: 0`，确保网络超时也不会把选/退课重复提交。
enum CourseSelectionHTTP
{
    static func send(
        urlString: String,
        method: String,
        cookie: String,
        parameters: [(String, String)] = [],
        accept: String = "application/json, text/javascript, */*; q=0.01",
        expectsJSON: Bool,
        retryCount: Int
    ) async throws -> (Data, HTTPURLResponse)
    {
        guard let url = URL(string: urlString) else
        {
            throw CourseSelectionServiceError.invalidURL
        }
        return try await send(
            url: url,
            method: method,
            cookie: cookie,
            parameters: parameters,
            accept: accept,
            expectsJSON: expectsJSON,
            retryCount: retryCount
        )
    }

    static func send(
        url: URL,
        method: String,
        cookie: String,
        parameters: [(String, String)] = [],
        accept: String = "application/json, text/javascript, */*; q=0.01",
        expectsJSON: Bool,
        retryCount: Int
    ) async throws -> (Data, HTTPURLResponse)
    {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue(CourseSelectionEndpoint.origin, forHTTPHeaderField: "Origin")
        request.setValue(CourseSelectionEndpoint.index, forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue(cookie, forHTTPHeaderField: "Cookie")

        if method.uppercased() == "POST"
        {
            request.httpBody = formEncodedData(parameters)
        }

        ChooseCourseDebug.request(
            url: url,
            method: method,
            parameters: parameters,
            retryCount: retryCount,
            hasCookie: !cookie.isEmpty
        )
        do
        {
            let (data, response) = try await NetworkService.perform(request: request, retries: retryCount)
            guard let httpResponse = response as? HTTPURLResponse else
            {
                throw CourseSelectionServiceError.invalidResponse("教务服务")
            }
            ChooseCourseDebug.response(url: url, response: httpResponse, data: data)
            try validate(httpResponse: httpResponse, data: data, expectsJSON: expectsJSON)
            return (data, httpResponse)
        }
        catch
        {
            ChooseCourseDebug.requestFailed(url: url, error: error)
            throw error
        }
    }

    static func urlByAppendingQueryItems(
        _ urlString: String,
        parameters: [(String, String)]
    ) throws -> URL
    {
        guard var components = URLComponents(string: urlString) else
        {
            throw CourseSelectionServiceError.invalidURL
        }
        var queryItems = components.queryItems ?? []
        queryItems.append(contentsOf: parameters.map { URLQueryItem(name: $0.0, value: $0.1) })
        components.queryItems = queryItems
        guard let url = components.url else
        {
            throw CourseSelectionServiceError.invalidURL
        }
        return url
    }

    static func formEncodedData(_ parameters: [(String, String)]) -> Data?
    {
        parameters
            .map { "\(formEncode($0.0))=\(formEncode($0.1))" }
            .joined(separator: "&")
            .data(using: .utf8)
    }

    static func formEncode(_ value: String) -> String
    {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    static func validate(httpResponse: HTTPURLResponse, data: Data, expectsJSON: Bool) throws
    {
        if httpResponse.statusCode == 910
        {
            throw CourseSelectionServiceError.invalidResponse("选课页上下文")
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else
        {
            throw CourseSelectionServiceError.serverError(operation: "教务服务", statusCode: httpResponse.statusCode)
        }

        let responseText = String(data: data, encoding: .utf8) ?? ""
        if looksLikeLoginPage(responseText)
        {
            throw CourseSelectionServiceError.sessionExpired
        }
        if expectsJSON && responseText.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<")
        {
            throw CourseSelectionServiceError.invalidResponse("教务服务")
        }
    }

    static func looksLikeLoginPage(_ text: String) -> Bool
    {
        text.contains("统一身份认证")
            || text.contains("用户登录")
            || text.contains("cas-paas.hzau.edu.cn/cas/login")
            || text.contains("name=\"execution\"")
    }
}

/// 按网页真实步骤加载 Index 与 Display 片段，得到当前会话的选课上下文。
enum CourseSelectionPageLoader
{
    static func load(
        cookie: String,
        semester: SelectedCourseSemester,
        category: CourseCatalogCategory? = nil
    ) async throws -> CourseSelectionContext
    {
        ChooseCourseDebug.info("开始加载选课页上下文：\(semester.displayName)")
        let (indexData, _) = try await CourseSelectionHTTP.send(
            urlString: CourseSelectionEndpoint.index,
            method: "GET",
            cookie: cookie,
            accept: "text/html, */*; q=0.01",
            expectsJSON: false,
            retryCount: 1
        )
        let indexHTML = String(data: indexData, encoding: .utf8) ?? ""
        var context = CourseSelectionHTML.context(from: indexHTML).applying(semester)
        let pageRules = CourseSelectionHTML.catalogRules(from: indexHTML)
        ChooseCourseDebug.context("选课页入口", values: context.values)

        guard context.value("iskxk") != "0" else
        {
            ChooseCourseDebug.warning("选课页明确返回未开放选课（iskxk=0）")
            throw CourseSelectionServiceError.selectionClosed
        }

        let selectedRule: CourseCatalogRule?
        if let category
        {
            guard let rule = rule(for: category, pageRules: pageRules, context: context) else
            {
                ChooseCourseDebug.warning("当前账号未返回课程类别规则：\(category.title)")
                throw CourseSelectionServiceError.missingCategoryRule(category.title)
            }
            selectedRule = rule
            context = context.applying(rule)
            let source = pageRules.contains(rule) ? "页签" : "首页默认页签"
            ChooseCourseDebug.info("课程类别规则已从当前账号选课页读取：\(category.title)，来源=\(source)")
        }
        else
        {
            selectedRule = nil
        }

        // Index 是壳页；网页切换任何页签都会先写入它自己的 kklxdm / xkkz_id，
        // 再加载 Display 片段。这里复现同一顺序，确保不同专业、年级拿到对应规则。
        let displayParameters = [
            ("xkkz_id", context.value("xkkz_id")),
            ("xszxzt", context.value("xszxzt")),
            ("kspage", "0"),
            ("jspage", "0")
        ]
        let (displayData, _) = try await CourseSelectionHTTP.send(
            urlString: CourseSelectionEndpoint.display,
            method: "POST",
            cookie: cookie,
            parameters: displayParameters,
            accept: "text/html, */*; q=0.01",
            expectsJSON: false,
            retryCount: 1
        )
        let displayHTML = String(data: displayData, encoding: .utf8) ?? ""
        context = context.merged(with: CourseSelectionHTML.context(from: displayHTML))
        if let selectedRule
        {
            // Display 会返回选中页签的完整开关；再次写入两个页签参数，防止模板内的
            // `firstXkkzId` 回填为首页规则。
            context = context.applying(selectedRule)
        }
        context = context.applyingFrontendRuleValues().applying(semester)
        let overview = context.overview
        ChooseCourseDebug.info(
            "选课页展示信息：\(overview.selectionTitle.ifEmpty("未返回学年/轮次"))，倒计时=\(overview.countdownText() ?? "未返回")"
        )
        ChooseCourseDebug.context(
            "选课页初始化",
            values: context.values,
            requiredFields: CourseSelectionContext.selectionRequiredFields
        )
        return context
    }

    /// `queryCourse(...)` 就是网页五个页签的真实规则来源。极少数旧模板未把页签
    /// 直接渲染成可解析的链接时，只允许复用首页默认页签（App 的首项“主修”）；
    /// 其它类别宁可明确提示，也不能拿别的账号或别的页签的规则 ID 猜测请求。
    private static func rule(
        for category: CourseCatalogCategory,
        pageRules: [CourseCatalogRule],
        context: CourseSelectionContext
    ) -> CourseCatalogRule?
    {
        if let rule = pageRules.first(where: { $0.category == category })
        {
            return rule
        }

        guard category == .major else { return nil }
        let courseTypeCode = context.value("kklxdm").ifEmpty(context.value("firstKklxdm"))
        let controlID = context.value("xkkz_id").ifEmpty(context.value("firstXkkzId"))
        guard !courseTypeCode.isEmpty, !controlID.isEmpty else { return nil }
        return CourseCatalogRule(
            category: .major,
            courseTypeCode: courseTypeCode,
            controlID: controlID
        )
    }
}

/// 模仿正方页面的只读课程检索链路。
final class SearchCourse
{
    static let shared = SearchCourse()

    func search(
        keyword: String,
        cookie: String,
        semester: SelectedCourseSemester
    ) async throws -> [CourseSearchResult]
    {
        let normalizedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKeyword.isEmpty else
        {
            throw CourseSelectionServiceError.noSearchResult
        }

        ChooseCourseDebug.info("开始搜索课程：关键词长度=\(normalizedKeyword.count)，学期=\(semester.displayName)")
        let pageContext = try await CourseSelectionPageLoader.load(cookie: cookie, semester: semester)
        var parameters = catalogParameters(context: pageContext, rangeStart: 1, rangeEnd: 10)
        parameters.append(contentsOf: searchBoxParameters(for: normalizedKeyword))

        let (data, _) = try await CourseSelectionHTTP.send(
            urlString: CourseSelectionEndpoint.catalog,
            method: "POST",
            cookie: cookie,
            parameters: parameters,
            expectsJSON: true,
            retryCount: 1
        )
        let payload = try CourseSelectionJSON.object(from: data, operation: "课程目录")

        var candidateContext = pageContext
        for (key, value) in parameters where key == "filterKey" || key.hasPrefix("filter_list[")
        {
            candidateContext.values[key] = value
        }
        let parsedCandidates = parseCatalog(payload: payload, context: candidateContext)
        let candidates = parsedCandidates.filter { matches($0, keyword: normalizedKeyword) }
        ChooseCourseDebug.info("课程目录解析：服务端记录=\(parsedCandidates.count)，关键词匹配=\(candidates.count)")
        guard !candidates.isEmpty else
        {
            ChooseCourseDebug.warning("课程搜索没有得到可用匹配结果")
            throw CourseSelectionServiceError.noSearchResult
        }

        let resolved = try await resolveCurrentParentClasses(candidates, cookie: cookie)
        ChooseCourseDebug.info("主教学班补全完成：可展示结果=\(resolved.count)")
        return resolved
    }

    /// 加载选课主页某个类别的一段课程目录。
    ///
    /// 这里故意只解析课程目录，不提前为每一门课请求教学班详情。目录可能一次返回
    /// 十门课，只有用户真正点“选课”时才需要短期教学班 token；延迟读取能明显减少
    /// 首屏等待，也避免无意义地给教务系统发送大量请求。
    func loadCatalog(
        category: CourseCatalogCategory,
        rangeStart: Int,
        rangeEnd: Int,
        cookie: String,
        semester: SelectedCourseSemester,
        keyword: String = ""
    ) async throws -> CourseCatalogPage
    {
        guard rangeStart > 0, rangeEnd >= rangeStart else
        {
            throw CourseSelectionServiceError.invalidResponse("课程目录区间")
        }

        let normalizedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        ChooseCourseDebug.info(
            "开始加载课程目录：类别=\(category.title)，区间=\(rangeStart)-\(rangeEnd)，搜索词长度=\(normalizedKeyword.count)，\(semester.displayName)"
        )
        // 每次切换分类都按网页的 queryCourse → Display 顺序，读取当前账号对应的规则。
        // 不能把其它账号抓到的 xkkz_id / 年级 / 专业参数覆盖进来。
        var categoryContext = try await CourseSelectionPageLoader.load(
            cookie: cookie,
            semester: semester,
            category: category
        )
        var parameters = catalogParameters(
            context: categoryContext,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd
        )
        if !normalizedKeyword.isEmpty
        {
            // 与网页 searchBox 完全相同：关键字必须转换为 filterKey / filter_list[n]。
            // 不能把课程名直接塞进 kcmc，否则某些类别会静默返回全部课程。
            let searchParameters = searchBoxParameters(for: normalizedKeyword)
            parameters.append(contentsOf: searchParameters)
            for (key, value) in searchParameters
            {
                categoryContext.values[key] = value
            }
        }
        let (data, _) = try await CourseSelectionHTTP.send(
            urlString: CourseSelectionEndpoint.catalog,
            method: "POST",
            cookie: cookie,
            parameters: parameters,
            expectsJSON: true,
            retryCount: 1
        )
        let payload = try CourseSelectionJSON.object(from: data, operation: "课程目录")
        let allCourses = parseCatalog(payload: payload, context: categoryContext)
        // 部分正方模板会忽略 filter_list；再在客户端做一次只读过滤，保证搜索框的
        // 结果不会混入无关课程。
        let matchedCourses = normalizedKeyword.isEmpty
            ? allCourses
            : allCourses.filter { matches($0, keyword: normalizedKeyword) }
        let courses = catalogSummaries(from: matchedCourses)
        let returnedCount = CourseSelectionJSON.catalogRows(in: payload).count
        let hasMore = catalogHasMore(
            payload: payload,
            returnedCount: returnedCount,
            requestedStart: rangeStart,
            requestedEnd: rangeEnd
        )
        ChooseCourseDebug.info(
            "课程目录解析：类别=\(category.title)，服务端记录=\(returnedCount)，可展示=\(courses.count)，还有更多=\(hasMore ? "是" : "否")"
        )
        return CourseCatalogPage(
            courses: courses,
            hasMore: hasMore,
            nextRangeStart: rangeEnd + 1,
            semester: categoryContext.resolvedSemester(fallback: semester),
            overview: categoryContext.overview
        )
    }

    /// 只为用户刚点开的课程补全当前会话的主教学班参数。
    /// 目录浏览不调用这个方法，因此不会为屏幕外课程提前生成临时凭据。
    func resolveCurrentParentClasses(
        for course: CourseSearchResult,
        cookie: String
    ) async throws -> [CourseSearchResult]
    {
        try await resolveCurrentParentClasses([course], cookie: cookie)
    }

    /// 展开课程卡片时强制重新读取一次教学班列表。目录摘要偶尔会包含某一个班的
    /// 临时参数；若直接复用它，只会展示一条而漏掉同课程的其它教学班。
    func loadCurrentTeachingClasses(
        for course: CourseSearchResult,
        cookie: String
    ) async throws -> [CourseSearchResult]
    {
        try await resolveCurrentParentClasses([course], cookie: cookie, forceRefresh: true)
    }

    /// 只在课程存在多层教学班时调用。单层课程会直接由 CourseEdit 进入确认步骤。
    func loadChildClasses(
        for course: CourseSearchResult,
        cookie: String,
        semester: SelectedCourseSemester
    ) async throws -> [CourseChildClass]
    {
        guard course.hasCurrentSelectionParameters else
        {
            ChooseCourseDebug.error("读取子教学班前缺少当前主教学班参数")
            throw CourseSelectionServiceError.missingCurrentParameters
        }
        guard course.requiresChildClass else
        {
            ChooseCourseDebug.info("课程为单层教学班，跳过子教学班 Sheet")
            return [Self.directClass(for: course)]
        }

        ChooseCourseDebug.info("开始读取子教学班：课程号=\(course.courseCode)，层级=\(course.classLevels)")

        let dialogParameters = [
            ("jxb_id", course.teachingClassID),
            ("do_jxb_id", course.selectionToken),
            ("jxbzls", String(course.classLevels)),
            ("rlkz", course.context.value("rlkz")),
            ("fxbj", course.context.value("fxbj")),
            ("cxbj", course.context.value("cxbj")),
            ("rlzlkz", course.context.value("rlzlkz")),
            ("rwlx", course.context.value("rwlx")),
            ("syqz", course.context.value("syqz").isEmpty ? "100" : course.context.value("syqz")),
            ("time", String(Int(Date().timeIntervalSince1970 * 1000)))
        ]
        let dialogURL = try CourseSelectionHTTP.urlByAppendingQueryItems(
            CourseSelectionEndpoint.childDialog,
            parameters: dialogParameters
        )
        let (dialogData, _) = try await CourseSelectionHTTP.send(
            url: dialogURL,
            method: "POST",
            cookie: cookie,
            accept: "text/html, */*; q=0.01",
            expectsJSON: false,
            retryCount: 1
        )
        let dialogHTML = String(data: dialogData, encoding: .utf8) ?? ""
        let dialogContext = course.context
            .merged(with: CourseSelectionHTML.context(from: dialogHTML))
            .applying(semester)
        ChooseCourseDebug.context("子教学班弹窗", values: dialogContext.values)

        var displayParameters = CourseSelectionContext.childDisplayFields.map { ($0, dialogContext.value($0)) }
        displayParameters.append(("jxb_id", course.selectionToken))
        displayParameters.append(("jxbzls", String(course.classLevels)))
        displayParameters.append(("syqz", dialogContext.value("syqz").isEmpty ? "100" : dialogContext.value("syqz")))
        let (displayData, _) = try await CourseSelectionHTTP.send(
            urlString: CourseSelectionEndpoint.childDisplay,
            method: "POST",
            cookie: cookie,
            parameters: displayParameters,
            expectsJSON: true,
            retryCount: 1
        )
        let payload = try CourseSelectionJSON.object(from: displayData, operation: "子教学班列表")
        let children = parseChildClasses(payload: payload, parentToken: course.selectionToken)
        ChooseCourseDebug.info("子教学班解析完成：可选择子班=\(children.count)")
        guard !children.isEmpty else
        {
            ChooseCourseDebug.warning("子教学班列表没有返回带有效选择参数的叶子班")
            throw CourseSelectionServiceError.noChildClass
        }
        return children
    }

    static func directClass(for course: CourseSearchResult) -> CourseChildClass
    {
        CourseChildClass(
            name: course.teachingClassName.isEmpty ? course.courseName : course.teachingClassName,
            teacher: "--",
            schedule: "--",
            location: "--",
            selectedCount: course.selectedCount,
            capacity: course.capacity,
            selectionTokens: [course.selectionToken]
        )
    }

    private func catalogParameters(
        context: CourseSelectionContext,
        rangeStart: Int,
        rangeEnd: Int
    ) -> [(String, String)]
    {
        var parameters = CourseSelectionContext.catalogFields.map { ($0, context.value($0)) }
        parameters.append(("kspage", String(rangeStart)))
        parameters.append(("jspage", String(rangeEnd)))

        // 页面会始终带上这个字段，即使值为空；省略它会让正方落入另一条查询分支。
        parameters.append(("jxbzb", context.value("jxbzb")))
        if context.value("jxbzhkg") == "1"
        {
            parameters.append(("zh", context.value("zh")))
        }
        return parameters
    }

    private func catalogHasMore(
        payload: Any,
        returnedCount: Int,
        requestedStart: Int,
        requestedEnd: Int
    ) -> Bool
    {
        // 部分正方模板即使返回了 tmpList，仍把 totalResult 固定写为 0；
        // 这种 0 不是可靠总数，改用本段是否返回满记录来继续判断。
        if let total = CourseSelectionJSON.totalResult(in: payload), total > 0
        {
            return total > requestedEnd
        }
        // 没有总数时，正方通常用“返回满一段”表示仍可能有下一段。
        return returnedCount >= (requestedEnd - requestedStart + 1)
    }

    /// PartDisplay 的 `tmpList` 常常按教学班而不是按课程聚合。移动端首层只展示
    /// 一张课程卡片，用户展开后再看到每一个教学班，信息密度会比网页表格自然得多。
    private func catalogSummaries(from courses: [CourseSearchResult]) -> [CourseSearchResult]
    {
        var order: [String] = []
        var grouped: [String: [CourseSearchResult]] = [:]
        for course in courses
        {
            let identity = course.courseID.ifEmpty(course.courseCode).ifEmpty(course.courseName)
            if grouped[identity] == nil { order.append(identity) }
            grouped[identity, default: []].append(course)
        }
        return order.compactMap
        { identity in
            guard let group = grouped[identity], let first = group.first else { return nil }
            let catalogTeachingClasses = group.map
            {
                CourseSearchResult.CatalogTeachingClass(
                    teachingClassID: $0.teachingClassID,
                    teachingClassName: $0.teachingClassName,
                    credit: $0.credit,
                    classLevels: $0.classLevels,
                    teachingClassComposition: $0.teachingClassComposition,
                    teacherInfo: $0.teacherInfo,
                    classTime: $0.classTime,
                    location: $0.location,
                    courseMaterial: $0.courseMaterial,
                    selectionRemark: $0.selectionRemark,
                    courseNature: $0.courseNature,
                    teachingMode: $0.teachingMode,
                    selectedCount: $0.selectedCount,
                    capacity: $0.capacity
                )
            }
            return first.catalogSummary(
                teachingClassCount: group.count,
                catalogTeachingClasses: catalogTeachingClasses
            )
        }
    }

    private func resolveCurrentParentClasses(
        _ courses: [CourseSearchResult],
        cookie: String,
        forceRefresh: Bool = false
    ) async throws -> [CourseSearchResult]
    {
        var resolved: [CourseSearchResult] = []
        ChooseCourseDebug.info("开始检查主教学班参数：候选=\(courses.count)")
        for course in courses
        {
            if course.hasCurrentSelectionParameters, !forceRefresh
            {
                ChooseCourseDebug.info("主教学班已有当前会话参数：课程号=\(course.courseCode)")
                resolved.append(course)
                continue
            }

            ChooseCourseDebug.info("主教学班参数缺失，开始补全：课程号=\(course.courseCode)")

            var parameters = CourseSelectionContext.parentClassFields.map { ($0, course.context.value($0)) }
            for (key, value) in course.context.values where key == "filterKey" || key.hasPrefix("filter_list[")
            {
                parameters.append((key, value))
            }
            parameters.append(("kch_id", course.courseID))
            let (data, _) = try await CourseSelectionHTTP.send(
                urlString: CourseSelectionEndpoint.parentClass,
                method: "POST",
                cookie: cookie,
                parameters: parameters,
                expectsJSON: true,
                retryCount: 1
            )
            let payload = try CourseSelectionJSON.object(from: data, operation: "主教学班补全")
            let serverClassCount = CourseSelectionJSON.classRows(in: payload).count
            let classes = parseParentClasses(payload: payload, replacing: course)
            ChooseCourseDebug.info(
                "主教学班补全解析：课程号=\(course.courseCode)，服务端教学班=\(serverClassCount)，可用教学班=\(classes.count)"
            )
            guard !classes.isEmpty else
            {
                ChooseCourseDebug.error("主教学班补全未返回可用的临时参数")
                throw CourseSelectionServiceError.missingCurrentParameters
            }
            resolved.append(contentsOf: classes)
        }
        return resolved
    }

    private func parseCatalog(payload: Any, context: CourseSelectionContext) -> [CourseSearchResult]
    {
        var seen = Set<String>()
        return CourseSelectionJSON.catalogRows(in: payload).compactMap
        { row in
            let courseID = CourseSelectionJSON.string(in: row, keys: ["kch_id", "kch", "t_kch_id"])
            let courseCode = CourseSelectionJSON.string(in: row, keys: ["kch", "kch_id", "t_kch_id"])
            let courseName = CourseSelectionJSON.courseName(CourseSelectionJSON.string(in: row, keys: ["kcmc", "kcmc_display", "course_name"]))
            guard !courseID.isEmpty, !courseName.isEmpty else { return nil }

            let classID = CourseSelectionJSON.string(in: row, keys: ["jxb_id", "jxbid", "jxbId", "jxbID"])
            let token = CourseSelectionJSON.string(in: row, keys: ["do_jxb_id", "dojxbid", "doJxbId", "doJxbID"])
            let identity = "\(courseID)|\(classID)|\(token)|\(courseName)"
            guard seen.insert(identity).inserted else { return nil }

            var rowContext = context
            for field in CourseSelectionContext.responseFields
            {
                let value = CourseSelectionJSON.string(in: row, keys: [field])
                if !value.isEmpty
                {
                    rowContext.values[field == "jg_id_1" ? "jg_id" : field] = value
                }
            }
            return CourseSearchResult(
                courseCode: courseCode,
                courseID: courseID,
                courseName: courseName,
                teachingClassName: CourseSelectionJSON.string(in: row, keys: ["jxbmc"]),
                credit: CourseSelectionJSON.string(in: row, keys: ["xf", "zixf"]),
                classLevels: CourseSelectionJSON.integer(in: row, keys: ["jxbzls", "jxbZls"], defaultValue: 1),
                teachingClassID: classID,
                selectionToken: token,
                context: rowContext,
                selectionCaption: CourseSelectionJSON.string(in: row, keys: ["kcmc_xk", "kcmc_display", "kcmcDisplay", "kcmc"]),
                teachingClassComposition: CourseSelectionJSON.string(in: row, keys: ["jxbzc", "jxbzucc", "teaching_class_composition"]),
                teacherInfo: CourseSelectionJSON.string(in: row, keys: ["jsxx", "jsxm", "jsmc", "teacher"]),
                classTime: CourseSelectionJSON.string(in: row, keys: ["sksj", "sksjmc", "sksj_display", "schedule"]),
                location: CourseSelectionJSON.string(in: row, keys: ["jxdd", "jxcd", "jxlmc", "location"]),
                courseMaterial: CourseSelectionJSON.string(in: row, keys: ["jcmc", "kczl", "course_material"]),
                selectionRemark: CourseSelectionJSON.string(in: row, keys: ["xkbz", "bz", "remark", "selection_remark"]),
                courseNature: CourseSelectionJSON.string(in: row, keys: ["kcxzmc", "kcxz", "kklxmc", "course_nature"]),
                teachingMode: CourseSelectionJSON.string(in: row, keys: ["jxmsmc", "jxms", "teaching_mode"]),
                selectedCount: CourseSelectionJSON.string(in: row, keys: ["jxbrs", "yxzrs", "yxrs", "selected_count"]),
                capacity: CourseSelectionJSON.string(in: row, keys: ["jxbrl", "kyrs", "capacity", "jxbrs"])
            )
        }
    }

    private func parseParentClasses(payload: Any, replacing course: CourseSearchResult) -> [CourseSearchResult]
    {
        var seen = Set<String>()
        return CourseSelectionJSON.classRows(in: payload).compactMap
        { row in
            let returnedCourseID = CourseSelectionJSON.string(in: row, keys: ["kch_id", "kchId", "t_kch_id"])
            let returnedCourseCode = CourseSelectionJSON.string(in: row, keys: ["kch", "course_code"])
            guard returnedCourseID.isEmpty || [course.courseID, course.courseCode].contains(returnedCourseID) else { return nil }
            guard returnedCourseCode.isEmpty || [course.courseID, course.courseCode].contains(returnedCourseCode) else { return nil }

            let classID = CourseSelectionJSON.string(in: row, keys: ["jxb_id", "jxbid", "jxbId", "jxbID"])
            let token = CourseSelectionJSON.string(in: row, keys: ["do_jxb_id", "dojxbid", "doJxbId", "doJxbID"])
            guard !classID.isEmpty, !token.isEmpty else { return nil }
            guard seen.insert("\(classID)|\(token)").inserted else { return nil }

            // 当前账号的补全接口常只返回 jxb_id、教师、时间、地点、容量和临时 token。
            // 教学班名称、组成、已选人数仍在目录摘要里；必须按 ID 精确回填，不能一律
            // 退回首层课程卡片的第一条资料。
            let normalizedClassID = classID.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let catalogClass = course.catalogTeachingClasses.first
            {
                $0.teachingClassID
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .uppercased() == normalizedClassID
            }
            let fallbackTeachingClassName = (catalogClass?.teachingClassName ?? "").ifEmpty(course.teachingClassName)
            let fallbackCredit = (catalogClass?.credit ?? "").ifEmpty(course.credit)
            let fallbackClassLevels = catalogClass?.classLevels ?? course.classLevels
            let fallbackComposition = (catalogClass?.teachingClassComposition ?? "").ifEmpty(course.teachingClassComposition)
            let fallbackTeacher = (catalogClass?.teacherInfo ?? "").ifEmpty(course.teacherInfo)
            let fallbackClassTime = (catalogClass?.classTime ?? "").ifEmpty(course.classTime)
            let fallbackLocation = (catalogClass?.location ?? "").ifEmpty(course.location)
            let fallbackMaterial = (catalogClass?.courseMaterial ?? "").ifEmpty(course.courseMaterial)
            let fallbackRemark = (catalogClass?.selectionRemark ?? "").ifEmpty(course.selectionRemark)
            let fallbackNature = (catalogClass?.courseNature ?? "").ifEmpty(course.courseNature)
            let fallbackTeachingMode = (catalogClass?.teachingMode ?? "").ifEmpty(course.teachingMode)
            let fallbackSelectedCount = (catalogClass?.selectedCount ?? "").ifEmpty(course.selectedCount)
            let fallbackCapacity = (catalogClass?.capacity ?? "").ifEmpty(course.capacity)

            var context = course.context
            for field in CourseSelectionContext.responseFields
            {
                let value = CourseSelectionJSON.string(in: row, keys: [field])
                if !value.isEmpty
                {
                    context.values[field == "jg_id_1" ? "jg_id" : field] = value
                }
            }
            return CourseSearchResult(
                courseCode: course.courseCode,
                courseID: course.courseID,
                courseName: course.courseName,
                teachingClassName: CourseSelectionJSON.string(in: row, keys: ["jxbmc", "jxb_name", "jxbName"]).ifEmpty(fallbackTeachingClassName),
                credit: CourseSelectionJSON.string(in: row, keys: ["xf", "zixf"]).ifEmpty(fallbackCredit),
                classLevels: CourseSelectionJSON.integer(in: row, keys: ["jxbzls", "jxbZls"], defaultValue: fallbackClassLevels),
                teachingClassID: classID,
                selectionToken: token,
                context: context,
                selectionCaption: course.selectionCaption,
                teachingClassComposition: CourseSelectionJSON.string(in: row, keys: ["jxbzc", "jxbzucc", "teaching_class_composition"]).ifEmpty(fallbackComposition),
                teacherInfo: CourseSelectionJSON.string(in: row, keys: ["jsxx", "jsxm", "jsmc", "teacher"]).ifEmpty(fallbackTeacher),
                classTime: CourseSelectionJSON.string(in: row, keys: ["sksj", "sksjmc", "sksj_display", "schedule"]).ifEmpty(fallbackClassTime),
                location: CourseSelectionJSON.string(in: row, keys: ["jxdd", "jxcd", "jxlmc", "location"]).ifEmpty(fallbackLocation),
                courseMaterial: CourseSelectionJSON.string(in: row, keys: ["jcmc", "kczl", "course_material"]).ifEmpty(fallbackMaterial),
                selectionRemark: CourseSelectionJSON.string(in: row, keys: ["xkbz", "bz", "remark", "selection_remark"]).ifEmpty(fallbackRemark),
                courseNature: CourseSelectionJSON.string(in: row, keys: ["kcxzmc", "kcxz", "kklxmc", "course_nature"]).ifEmpty(fallbackNature),
                teachingMode: CourseSelectionJSON.string(in: row, keys: ["jxmsmc", "jxms", "teaching_mode"]).ifEmpty(fallbackTeachingMode),
                selectedCount: CourseSelectionJSON.string(in: row, keys: ["jxbrs", "yxzrs", "yxrs", "selected_count"]).ifEmpty(fallbackSelectedCount),
                capacity: CourseSelectionJSON.string(in: row, keys: ["jxbrl", "kyrs", "capacity", "jxbrs"]).ifEmpty(fallbackCapacity),
                catalogTeachingClassCount: course.catalogTeachingClassCount,
                catalogTeachingClasses: course.catalogTeachingClasses
            )
        }
    }

    private func parseChildClasses(payload: Any, parentToken: String) -> [CourseChildClass]
    {
        let allRows = CourseSelectionJSON.classRows(in: payload)
        let nestedRows = allRows.filter
        {
            let parentID = CourseSelectionJSON.string(in: $0, keys: ["fjxb_id", "fjxbId", "parent_jxb_id"])
            return !parentID.isEmpty && parentID != "0" && parentID != "-1"
        }
        let rows: [[String: Any]]
        if !nestedRows.isEmpty
        {
            rows = nestedRows
        }
        else
        {
            // 有些页面不返回 fjxb_id，却会同时放一行“讲课/理论”摘要与实际子班。
            // 只有在同一响应中确实存在其它子班时才过滤摘要，避免误丢合法单行结果。
            let nonLectureRows = allRows.filter
            {
                let classKind = CourseSelectionJSON.string(in: $0, keys: ["xsmc", "xs_mc"])
                return !["", "讲课", "理论"].contains(classKind)
            }
            rows = !nonLectureRows.isEmpty && nonLectureRows.count < allRows.count ? nonLectureRows : allRows
        }
        var seen = Set<String>()

        return rows.compactMap
        { row in
            let tokens = CourseSelectionJSON.childSelectionTokens(from: row, parentToken: parentToken)
            // 多层课程若只有父班 token，说明这只是摘要行，不能把它当作子班提交。
            guard tokens.count > 1 else { return nil }
            let identity = tokens.joined(separator: ",")
            guard seen.insert(identity).inserted else { return nil }

            // 子教学班接口明确返回 jxbrs=已选人数、jxbrl=容量，例如 30 / 36。
            // 不把两者拼成展示字符串，后续才能统一判断“已满”和剩余比例。
            let selected = CourseSelectionJSON.string(in: row, keys: ["jxbrs", "yxzrs", "yxrs", "selected_count"])
            let capacity = CourseSelectionJSON.string(in: row, keys: ["jxbrl", "kyrs", "capacity"])

            return CourseChildClass(
                name: CourseSelectionJSON.displayText(CourseSelectionJSON.string(in: row, keys: ["jxbmc", "xsmc", "kcmc", "jxb_name", "name"])).ifEmpty("子教学班"),
                teacher: CourseSelectionJSON.teacherName(CourseSelectionJSON.displayText(CourseSelectionJSON.string(in: row, keys: ["jsxm", "jsxx", "jsmc", "teacher"]))).ifEmpty("--"),
                schedule: CourseSelectionJSON.displayText(CourseSelectionJSON.string(in: row, keys: ["sksj", "sksjmc", "sksj_display", "schedule"])).ifEmpty("--"),
                location: CourseSelectionJSON.displayText(CourseSelectionJSON.string(in: row, keys: ["jxdd", "jxcd", "jxlmc", "location"])).ifEmpty("--"),
                selectedCount: selected,
                capacity: capacity,
                selectionTokens: tokens
            )
        }
    }

    private func searchBoxParameters(for keyword: String) -> [(String, String)]
    {
        let terms = keyword.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !terms.isEmpty else { return [] }
        return [("filterKey", "all")] + terms.enumerated().map { ("filter_list[\($0.offset)]", $0.element) }
    }

    private func matches(_ course: CourseSearchResult, keyword: String) -> Bool
    {
        let query = keyword.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let source = "\(course.courseCode) \(course.courseName) \(course.teachingClassName)".lowercased()
        let compactQuery = query.replacingOccurrences(of: " ", with: "")
        let compactSource = source
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "（", with: "")
            .replacingOccurrences(of: "）", with: "")
        return source.contains(query) || (!compactQuery.isEmpty && compactSource.contains(compactQuery))
    }
}

private enum CourseSelectionHTML
{
    static func context(from html: String) -> CourseSelectionContext
    {
        var values: [String: String] = [:]
        let inputPattern = #"(?is)<(?:input|select|textarea)\b[^>]*>"#
        for tag in matches(for: inputPattern, in: html)
        {
            let names = [attribute("name", in: tag), attribute("id", in: tag)].compactMap { $0 }.filter { !$0.isEmpty }
            let value = attribute("value", in: tag) ?? ""
            for rawName in names
            {
                let name = rawName == "jg_id_1" ? "jg_id" : rawName
                guard CourseSelectionContext.responseFields.contains(rawName) || CourseSelectionContext.responseFields.contains(name) else { continue }
                if values[name] == nil || !value.isEmpty
                {
                    values[name] = value
                }
            }
        }

        // 部分页面只通过 JavaScript 给隐藏字段赋值；这里只读取页面明确写出的字面量。
        for rawName in CourseSelectionContext.responseFields
        {
            let name = rawName == "jg_id_1" ? "jg_id" : rawName
            guard values[name].isEmptyOrNil else { continue }
            let escapedName = NSRegularExpression.escapedPattern(for: rawName)
            let literal = #"(?:['\"]([^'\"]*)['\"]|(-?\d+(?:\.\d+)?|true|false))"#
            let patterns = [
                "(?is)(?:var|let|const)?\\s*\(escapedName)\\s*[:=]\\s*\(literal)",
                "(?is)\\$\\(\\s*['\"]#\(escapedName)['\"]\\s*\\)\\s*\\.val\\(\\s*\(literal)\\s*\\)"
            ]
            for pattern in patterns
            {
                if let match = firstCaptures(for: pattern, in: html)
                {
                    values[name] = match.first(where: { !$0.isEmpty }) ?? ""
                    break
                }
            }
        }

        // 选课规则的学分区间在部分模板中不是 input，而是正文里的 font 标签；
        // 截止时间则可能由内联脚本赋给 `sysj`。把它们收集成展示元数据，绝不混入
        // 最终选课 POST 所需的协议字段。
        for (key, value) in presentationMetadata(from: html)
        {
            if values[key].isEmptyOrNil || !value.isEmpty
            {
                values[key] = value
            }
        }
        return CourseSelectionContext(values: values).merged(with: CourseSelectionContext())
    }

    /// Index 页面的五个页签会渲染成 `queryCourse(this, kklxdm, xkkz_id)`。
    /// 这里仅解析网页已经给出的字面量，绝不由学号、专业或历史抓包推导规则 ID。
    static func catalogRules(from html: String) -> [CourseCatalogRule]
    {
        var rules: [CourseCatalogRule] = []
        var seen = Set<String>()
        let anchorPattern = #"(?is)<a\b[^>]*>.*?</a>"#

        for anchor in matches(for: anchorPattern, in: html)
        {
            let handlers = [attribute("onclick", in: anchor), attribute("href", in: anchor)]
                .compactMap { $0 }
            guard let arguments = handlers.lazy.compactMap(queryCourseArguments).first else { continue }

            let visibleTitle: String
            if let openingEnd = anchor.firstIndex(of: ">"),
               let closingStart = anchor.range(of: "</a", options: .caseInsensitive)?.lowerBound
            {
                visibleTitle = visibleText(from: String(anchor[anchor.index(after: openingEnd) ..< closingStart]))
            }
            else
            {
                visibleTitle = ""
            }
            let titles = [visibleTitle, attribute("title", in: anchor), attribute("data-original-title", in: anchor)]
                .compactMap { $0 }
            guard let category = CourseCatalogCategory.allCases.first(where: { candidate in
                titles.contains(where: candidate.matchesServerTitle)
            }) else { continue }

            let courseTypeCode = arguments.0.trimmingCharacters(in: .whitespacesAndNewlines)
            let controlID = arguments.1.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !courseTypeCode.isEmpty, !controlID.isEmpty else { continue }
            let identity = "\(category.rawValue)|\(courseTypeCode)|\(controlID)"
            guard seen.insert(identity).inserted else { continue }
            rules.append(
                CourseCatalogRule(
                    category: category,
                    courseTypeCode: courseTypeCode,
                    controlID: controlID
                )
            )
        }
        return rules
    }

    private static func queryCourseArguments(in handler: String) -> (String, String)?
    {
        // 兼容单双引号以及少数模板里未加引号的数值型开课类型。
        let pattern = #"(?is)\bqueryCourse\s*\(\s*[^,]+,\s*(?:['\"]([^'\"]+)['\"]|([^,\s)]+))\s*,\s*(?:['\"]([^'\"]+)['\"]|([^,\s)]+))\s*\)"#
        guard let captures = firstCaptures(for: pattern, in: handler) else { return nil }
        let values = captures.filter { !$0.isEmpty }
        guard values.count >= 2 else { return nil }
        return (values[0], values[1])
    }

    private static func presentationMetadata(from html: String) -> [String: String]
    {
        var values: [String: String] = [:]
        let text = visibleText(from: html)
        let creditPatterns: [(String, String)] = [
            ("selectionMinimumCredit", #"总学分最低\s*([0-9]+(?:\.[0-9]+)?)"#),
            ("selectionMaximumCredit", #"最高\s*([0-9]+(?:\.[0-9]+)?)"#),
            ("earnedCredit", #"已获得学分\s*([0-9]+(?:\.[0-9]+)?)"#),
            ("yxxfs", #"本学期已选学分\s*([0-9]+(?:\.[0-9]+)?)"#)
        ]
        for (key, pattern) in creditPatterns
        {
            if let value = firstCaptures(for: pattern, in: text)?.first, !value.isEmpty
            {
                values[key] = value
            }
        }

        // `yxxfs` 常由前端异步更新，优先读取带固定 id 的元素，避免正文中旧值覆盖它。
        let selectedCreditElement = #"(?is)<[^>]+\bid\s*=\s*['\"]yxxfs['\"][^>]*>(.*?)</[^>]+>"#
        if let content = firstCaptures(for: selectedCreditElement, in: html)?.first
        {
            let value = visibleText(from: content)
            if !value.isEmpty { values["yxxfs"] = value }
        }

        let countdownPattern = #"距选课结束还(?:剩|有)\s*[0-9]+\s*(?:天|小时|分钟)"#
        if let countdown = matches(for: countdownPattern, in: text).first
        {
            values["selectionCountdownText"] = countdown
        }

        // 正方不同模板对“结束时间”变量的命名不一致。只接受名称中明确表达结束的
        // 字段，并把解析留给 CourseSelectionOverview；不会把开始时间误作截止时间。
        let deadlineNames = ["xkjssj", "xk_jssj", "jssj", "jzsj", "endTime", "end_time", "endDate", "sysj"]
        for name in deadlineNames
        {
            let escapedName = NSRegularExpression.escapedPattern(for: name)
            let patterns = [
                "(?is)(?:var|let|const)?\\s*\(escapedName)\\s*[:=]\\s*(?:new\\s+Date\\s*\\()?\\s*['\"]([^'\"]+)['\"]",
                "(?is)\\$\\(\\s*['\"]#\(escapedName)['\"]\\s*\\)\\s*\\.val\\(\\s*['\"]([^'\"]+)['\"]"
            ]
            for pattern in patterns
            {
                if let value = firstCaptures(for: pattern, in: html)?.first,
                   !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                {
                    values[name] = value
                    break
                }
            }
        }
        return values
    }

    private static func visibleText(from html: String) -> String
    {
        let withoutBreaks = html
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "<br>", with: " ")
            .replacingOccurrences(of: "<br/>", with: " ")
            .replacingOccurrences(of: "<br />", with: " ")
        let withoutTags = withoutBreaks.replacingOccurrences(
            of: #"(?is)<[^>]+>"#,
            with: " ",
            options: .regularExpression
        )
        return withoutTags
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func attribute(_ name: String, in tag: String) -> String?
    {
        let escaped = NSRegularExpression.escapedPattern(for: name)
        let pattern = "(?is)(?:^|\\s)\(escaped)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>]+))"
        guard let captures = firstCaptures(for: pattern, in: tag) else { return nil }
        return captures.first(where: { !$0.isEmpty })
    }

    private static func matches(for pattern: String, in text: String) -> [String]
    {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex ..< text.endIndex, in: text)
        return expression.matches(in: text, range: range).compactMap
        { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }
    }

    private static func firstCaptures(for pattern: String, in text: String) -> [String]?
    {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        let searchRange = NSRange(text.startIndex ..< text.endIndex, in: text)
        guard let match = expression.firstMatch(in: text, range: searchRange) else { return nil }
        return (1 ..< match.numberOfRanges).compactMap
        { index in
            let range = match.range(at: index)
            guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else { return nil }
            return String(text[swiftRange])
        }
    }
}

private enum CourseSelectionJSON
{
    static func object(from data: Data, operation: String) throws -> Any
    {
        do
        {
            return try JSONSerialization.jsonObject(with: data, options: [])
        }
        catch
        {
            throw CourseSelectionServiceError.invalidResponse(operation)
        }
    }

    static func catalogRows(in value: Any) -> [[String: Any]]
    {
        rows(in: value, rowKeys: ["kcmc", "kch_id", "kch"], containerKeys: ["tmpList", "data", "rows", "items", "content", "result"])
    }

    static func classRows(in value: Any) -> [[String: Any]]
    {
        rows(in: value, rowKeys: ["jxb_id", "jxbmc", "do_jxb_id", "jxb_ids"], containerKeys: ["tmpList", "jxbList", "data", "rows", "items", "content", "result"])
    }

    /// 尝试读取目录响应里的总记录数。不同版本可能把它放在顶层或 queryModel 中；
    /// 没有总数时由调用方按“本段是否返回满 10 条”判断是否继续触底加载。
    static func totalResult(in value: Any) -> Int?
    {
        guard let object = value as? [String: Any] else { return nil }
        for key in ["totalResult", "totalCount", "total", "recordsTotal"]
        {
            if let total = integerValue(object[key]), total >= 0
            {
                return total
            }
        }
        for key in ["queryModel", "pageable", "pagination"]
        {
            if let nested = object[key], let total = totalResult(in: nested)
            {
                return total
            }
        }
        return nil
    }

    static func string(in row: [String: Any], keys: [String]) -> String
    {
        for key in keys
        {
            guard let rawValue = row[key] else { continue }
            let value: String
            switch rawValue
            {
            case let string as String:
                value = string
            case let number as NSNumber:
                value = number.stringValue
            default:
                continue
            }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return ""
    }

    static func integer(in row: [String: Any], keys: [String], defaultValue: Int) -> Int
    {
        Int(string(in: row, keys: keys)) ?? defaultValue
    }

    private static func integerValue(_ value: Any?) -> Int?
    {
        switch value
        {
        case let number as NSNumber:
            return number.intValue
        case let string as String:
            return Int(string.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            return nil
        }
    }

    static func courseName(_ rawValue: String) -> String
    {
        var value = displayText(rawValue)
        if let range = value.range(of: #"^\([^)]*\)"#, options: .regularExpression)
        {
            value.removeSubrange(range)
        }
        if let range = value.range(of: #"\s*简介\s*-\s*[^-]+\s*$"#, options: .regularExpression)
        {
            value.removeSubrange(range)
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func displayText(_ rawValue: String) -> String
    {
        rawValue
            // 教务接口把多段上课时间 / 地点直接放进 HTML 字符串；转换成换行后
            // SwiftUI 会自然排版，不会把 `<br/>` 原样泄露给用户。
            .replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: #"[ \t]*\n[ \t]*"#, with: "\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func teacherName(_ rawValue: String) -> String
    {
        rawValue
            .split(separator: ";", omittingEmptySubsequences: true)
            .map(String.init)
            .map
            { item in
                let parts = item.split(separator: "/", omittingEmptySubsequences: false)
                return parts.count >= 2 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : item.trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty }
            .joined(separator: "、")
    }

    static func childSelectionTokens(from row: [String: Any], parentToken: String) -> [String]
    {
        // 不同页面模板可能把 token 放在 data-* 字段或 onclick 中；全部只解析
        // 服务端返回的长十六进制 token，绝不从 jxb_id / 课程号推导。
        let rawTokens = [
            "do_jxb_id", "dojxbid", "doJxbId", "jxb_ids", "jxbids",
            "data_do_jxb_id", "data_jxb_ids", "onclick", "operation", "operate"
        ].compactMap { row[$0] }.compactMap(scalarString)
        var tokens: [String] = []
        for rawToken in rawTokens where !rawToken.isEmpty
        {
            for token in longHexTokens(in: rawToken)
            {
                if !tokens.contains(token)
                {
                    tokens.append(token)
                }
            }
        }
        guard !tokens.isEmpty, !(tokens.count == 1 && tokens[0] == parentToken) else { return [] }
        if tokens.contains(parentToken)
        {
            return [parentToken] + tokens.filter { $0 != parentToken }
        }
        return [parentToken] + tokens
    }

    private static func scalarString(_ value: Any) -> String?
    {
        switch value
        {
        case let string as String:
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    private static func longHexTokens(in value: String) -> [String]
    {
        let pattern = #"(?i)(?<![0-9a-f])[0-9a-f]{48,}(?![0-9a-f])"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(value.startIndex ..< value.endIndex, in: value)
        return expression.matches(in: value, range: range).compactMap
        { match in
            guard let tokenRange = Range(match.range, in: value) else { return nil }
            return String(value[tokenRange])
        }
    }

    private static func rows(in value: Any, rowKeys: [String], containerKeys: [String]) -> [[String: Any]]
    {
        if let rows = value as? [[String: Any]]
        {
            return rows
        }
        // `JSONSerialization` 在不同系统版本上可能桥接为 [Any] / NSArray，而不是
        // 直接可转换的 [[String: Any]]。主教学班接口恰好会返回顶层数组，因此逐项
        // 桥接一次，避免合法的三条教学班记录被误判成“无法识别”。
        if let values = value as? [Any]
        {
            let rows = values.compactMap { item -> [String: Any]? in
                if let row = item as? [String: Any] { return row }
                if let dictionary = item as? NSDictionary { return dictionary as? [String: Any] }
                return nil
            }
            if !rows.isEmpty { return rows }
        }
        guard let object = value as? [String: Any] else { return [] }
        if rowKeys.contains(where: { object[$0] != nil })
        {
            return [object]
        }
        for key in containerKeys
        {
            guard let nestedValue = object[key] else { continue }
            let nestedRows = rows(in: nestedValue, rowKeys: rowKeys, containerKeys: containerKeys)
            if !nestedRows.isEmpty { return nestedRows }
        }
        return []
    }
}

extension String
{
    func ifEmpty(_ fallback: String) -> String
    {
        isEmpty ? fallback : self
    }
}

/// 选课主页的课程目录 UI。
/// 目录分页由滚动位置驱动：最后一项出现时调用 `onReachEnd`，不再需要网页上的“点击查看更多”。
struct CourseCatalogView: View
{
    @Binding var category: CourseCatalogCategory
    let semester: SelectedCourseSemester
    let overview: CourseSelectionOverview
    let appliedSearchText: String
    let courses: [CourseSearchResult]
    let isLoading: Bool
    let isLoadingMore: Bool
    let hasMore: Bool
    let errorMessage: String?
    let loadMoreError: String?
    let expandedCourseKey: String?
    let expandedTeachingClasses: [String: [CourseSearchResult]]
    let expandingCourseKey: String?
    let expandedCourseError: String?
    let onRetry: () -> Void
    let onReachEnd: () -> Void
    let onToggleExpansion: (CourseSearchResult) -> Void
    let onRetryExpansion: (CourseSearchResult) -> Void
    let onSelectTeachingClass: (CourseSearchResult) -> Void
    /// 已选状态来自同一会话刚刷新过的 ChoosedDisplay；目录只负责显示和转交退选确认，
    /// 最终退选前仍会在 CourseEdit 里重新核验，绝不使用这里的旧 token 写入。
    let selectedCourseFor: (CourseSearchResult) -> SelectedCourse?
    let onRequestDrop: (SelectedCourse) -> Void

    var body: some View
    {
        Group
        {
            Section
            {
                CourseSelectionHeaderCard(overview: overview, semester: semester)
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 6, trailing: 12))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                // 用原生 Picker 保持类别选择的语义和辅助功能；五个名称用短标题避免
                // 在窄屏上把网页式按钮挤到不可读。
                Picker("课程类别", selection: $category)
                {
                    ForEach(CourseCatalogCategory.allCases)
                    { item in
                        Text(item.shortTitle).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .labelsHidden()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 6, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section
            {
                if isLoading, courses.isEmpty
                {
                    // 首屏加载提示由 ChooseCourseView 覆盖在页面正中；这里保留一行
                    // 占位，避免 List 在等待网络返回时短暂显示“没有课程”的空状态。
                    Color.clear
                        .frame(height: 1)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                else if let errorMessage
                {
                    catalogError(errorMessage)
                }
                else if let loadError = loadMoreError, courses.isEmpty
                {
                    catalogError(loadError)
                }
                else if courses.isEmpty
                {
                    VStack(spacing: 8)
                    {
                        Image(systemName: "tray")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text(appliedSearchText.isEmpty ? "暂时没有可选课程" : "没有找到匹配课程")
                            .font(.headline)
                        Text(appliedSearchText.isEmpty ? "当前类别没有返回课程，向下拉可以重试。" : "可修改搜索关键词后再次搜索。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                else
                {
                    ForEach(Array(courses.enumerated()), id: \.element.id)
                    { index, course in
                        let isExpanded = expandedCourseKey == course.catalogKey
                        CourseSearchResultRow(
                            course: course,
                            isExpanded: isExpanded,
                            teachingClasses: isExpanded ? (expandedTeachingClasses[course.catalogKey] ?? []) : [],
                            isLoadingTeachingClasses: expandingCourseKey == course.catalogKey,
                            detailError: isExpanded ? expandedCourseError : nil,
                            onToggle: { onToggleExpansion(course) },
                            onRetryDetails: { onRetryExpansion(course) },
                            onSelectTeachingClass: onSelectTeachingClass,
                            selectedCourseFor: selectedCourseFor,
                            onRequestDrop: onRequestDrop
                        )
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .onAppear
                        {
                            // SwiftUI 可能多次触发 onAppear；上层的 isLoadingMore 锁会
                            // 保证同一段区间只请求一次。
                            if index == courses.count - 1,
                               hasMore,
                               !isLoadingMore,
                               loadMoreError == nil
                            {
                                onReachEnd()
                            }
                        }
                    }

                    if let loadError = loadMoreError
                    {
                        VStack(spacing: 8)
                        {
                            Text(loadError)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("重试加载更多", action: onReachEnd)
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    else if isLoadingMore
                    {
                        HStack(spacing: 8)
                        {
                            ProgressView()
                            Text("正在加载更多课程…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    else if !hasMore
                    {
                        Text("已加载全部课程")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func catalogError(_ message: String) -> some View
    {
        VStack(spacing: 8)
        {
            Label("课程目录加载失败", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("重试", action: onRetry)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

/// 顶部信息完全取自 Index / Display 的当次响应；没有读取到截止时间时明确说明，
/// 不使用固定日期或猜测的开课周期。
private struct CourseSelectionHeaderCard: View
{
    let overview: CourseSelectionOverview
    let semester: SelectedCourseSemester

    private var title: String
    {
        let selectionTitle = overview.selectionTitle
        return selectionTitle.isEmpty ? "\(semester.displayName) 选课" : "\(selectionTitle) 选课"
    }

    var body: some View
    {
        VStack(alignment: .leading, spacing: 10)
        {
            Label(title, systemImage: "graduationcap.fill")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            TimelineView(.periodic(from: .now, by: 60))
            { timeline in
                if let countdown = overview.countdownText(at: timeline.date)
                {
                    Label(countdown, systemImage: "hourglass")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                else
                {
                    Label("教务页面暂未返回选课结束时间", systemImage: "hourglass.bottomhalf.filled")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}

/// 首层卡片没有“选课”按钮。轻点卡片展开后，用户能横向比较每个教学班的教师、时间、
/// 地点和容量，再点击那个具体教学班的按钮，降低误选概率。
private struct CourseSearchResultRow: View
{
    let course: CourseSearchResult
    let isExpanded: Bool
    let teachingClasses: [CourseSearchResult]
    let isLoadingTeachingClasses: Bool
    let detailError: String?
    let onToggle: () -> Void
    let onRetryDetails: () -> Void
    let onSelectTeachingClass: (CourseSearchResult) -> Void
    /// 每个教学班单独计算已选状态，不能把同一课程的状态套到所有教学班。
    let selectedCourseFor: (CourseSearchResult) -> SelectedCourse?
    let onRequestDrop: (SelectedCourse) -> Void

    var body: some View
    {
        VStack(alignment: .leading, spacing: 12)
        {
            Button(action: onToggle)
            {
                HStack(alignment: .top, spacing: 12)
                {
                    VStack(alignment: .leading, spacing: 7)
                    {
                        Text(course.courseName)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: 7)
                        {
                            if !course.courseCode.isEmpty
                            {
                                CourseCatalogTag(title: course.courseCode, color: .secondary)
                            }
                            if !course.credit.isEmpty
                            {
                                CourseCatalogTag(title: "\(course.credit) 学分", color: .secondary)
                            }
                            CourseCatalogTag(title: course.teachingClassCountText, color: .secondary)
                        }
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                        .padding(.top, 5)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(course.courseName)，\(isExpanded ? "收起教学班" : "展开教学班")")

            if isExpanded
            {
                Divider().overlay(Color.secondary.opacity(0.22))

                if isLoadingTeachingClasses
                {
                    // 读取提示由页面中央统一呈现，展开卡片本身不再额外顶出一行加载框。
                    Color.clear
                        .frame(height: 1)
                }
                else if let detailError
                {
                    VStack(alignment: .leading, spacing: 8)
                    {
                        Label("教学班详情读取失败", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.yellow)
                        Text(detailError)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("重新读取", action: onRetryDetails)
                            .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                }
                else if teachingClasses.isEmpty
                {
                    Text("暂未读取到可展示的教学班。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                }
                else
                {
                    ScrollView(.horizontal, showsIndicators: false)
                    {
                        LazyHStack(alignment: .top, spacing: 12)
                        {
                            ForEach(teachingClasses)
                            { teachingClass in
                                TeachingClassSelectionCard(
                                    course: teachingClass,
                                    selectedCourse: selectedCourseFor(teachingClass),
                                    onSelect: { onSelectTeachingClass(teachingClass) },
                                    onRequestDrop: onRequestDrop
                                )
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}

/// 一个横滑教学班卡片。所有字段来自本次 `cxJxbWithKch` / PartDisplay 响应；
/// 缺字段时仅显示“暂未提供”，不把上一门课的数据错误复用过来。
private struct TeachingClassSelectionCard: View
{
    let course: CourseSearchResult
    let selectedCourse: SelectedCourse?
    let onSelect: () -> Void
    let onRequestDrop: (SelectedCourse) -> Void

    private var capacityStatus: CourseCapacityStatus { course.capacityStatus }

    private var actionTitle: String
    {
        if let selectedCourse
        {
            guard selectedCourse.dropAllowed, !selectedCourse.selectionTokens.isEmpty else
            {
                return "已选（暂不可退）"
            }
            return "退选"
        }
        return course.requiresChildClass ? "继续选择子课程" : "选课"
    }

    private var actionTint: Color
    {
        selectedCourse == nil ? capacityStatus.tint : .red
    }

    private var isActionEnabled: Bool
    {
        if let selectedCourse
        {
            return selectedCourse.dropAllowed && !selectedCourse.selectionTokens.isEmpty
        }
        // 正方第一轮等阶段可以“不限容量”，页面也可能显示已选人数大于容量。
        // 因此“已满”只能是红色状态提示，不能成为客户端的最终否决条件；
        // 按钮只在缺少本会话 token 时禁用，最终是否选上交由服务器返回并核验。
        return course.hasCurrentSelectionParameters
    }

    var body: some View
    {
        VStack(alignment: .leading, spacing: 10)
        {
            // 教学班是这张卡片的标题；其余信息按用户浏览教学安排的顺序向下排。
            Text(displayText(course.teachingClassName, fallback: course.courseName))
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)

            // 容量紧跟教学班标题；动作按钮只表达“选课/退选”，用户无需在页面底部
            // 再回头确认人数。
            CourseCapacityBadge(status: capacityStatus)

            VStack(alignment: .leading, spacing: 8)
            {
                let teacher = teacherText(course.teacherInfo)
                if teacher != "暂未提供"
                {
                    TeachingClassDetailLine(
                        icon: "person.fill",
                        title: "上课教师",
                        text: teacher,
                        textFont: .subheadline.weight(.medium),
                        textColor: .primary
                    )
                }
                if !course.teachingClassComposition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                {
                    TeachingClassDetailLine(
                        icon: "person.2.fill",
                        title: "教学班组成",
                        text: displayText(course.teachingClassComposition),
                        textFont: .subheadline.weight(.bold),
                        textColor: .primary
                    )
                }
                if !course.classTime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                {
                    TeachingClassDetailLine(icon: "calendar", title: "上课时间", text: displayText(course.classTime))
                }
                if !course.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                {
                    TeachingClassDetailLine(
                        icon: "mappin.and.ellipse",
                        title: "教学地点",
                        text: displayText(course.location),
                        textFont: .caption.weight(.semibold),
                        textColor: .primary
                    )
                }
                if !course.courseMaterial.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                {
                    TeachingClassDetailLine(icon: "book.closed", title: "课程教材", text: displayText(course.courseMaterial))
                }
                if !course.courseNature.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                {
                    TeachingClassDetailLine(icon: "tag", title: "课程性质", text: displayText(course.courseNature))
                }
                if !course.teachingMode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                {
                    TeachingClassDetailLine(icon: "rectangle.3.group", title: "教学模式", text: displayText(course.teachingMode))
                }
                if !course.selectionRemark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                {
                    TeachingClassDetailLine(icon: "text.alignleft", title: "选课备注", text: displayText(course.selectionRemark))
                }
            }

            Button
            {
                if let selectedCourse
                {
                    onRequestDrop(selectedCourse)
                }
                else
                {
                    onSelect()
                }
            } label: {
                Text(actionTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(selectedCourse == nil ? capacityStatus.buttonForeground : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(actionTint.opacity(isActionEnabled ? 0.88 : 0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!isActionEnabled)
            .accessibilityLabel(actionTitle)
            .accessibilityHint(selectedCourse != nil ? "需要再次确认后才会提交退选" : (course.requiresChildClass ? "下一步选择子课程" : "会先由教务系统核验再提交一次选课请求"))
        }
        .padding(14)
        .frame(width: 322, alignment: .leading)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func displayText(_ value: String, fallback: String = "暂未提供") -> String
    {
        let trimmed = value
            .replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "--" ? fallback : trimmed
    }

    private func teacherText(_ value: String) -> String
    {
        let pieces = value.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        if pieces.count >= 2, !pieces[1].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return pieces[1]
        }
        return displayText(value)
    }
}

/// 容量只以紧凑标签展示在教学班标题下方，颜色沿用余量档位，但不会改变整张卡片的中性灰外观。
private struct CourseCapacityBadge: View
{
    let status: CourseCapacityStatus

    var body: some View
    {
        Text(status.availabilityText)
            .font(.caption.weight(.semibold))
            .foregroundStyle(status.tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(status.tint.opacity(0.16), in: Capsule())
    }
}

private struct TeachingClassDetailLine: View
{
    let icon: String
    let title: String
    let text: String
    var textFont: Font = .caption
    var textColor: Color = .secondary

    var body: some View
    {
        HStack(alignment: .top, spacing: 7)
        {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 14, alignment: .center)
            Text("\(title)：\(text)")
                .font(textFont)
                .foregroundStyle(textColor)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct CourseCatalogTag: View
{
    let title: String
    let color: Color

    var body: some View
    {
        Text(title)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(color.opacity(0.14), in: Capsule())
    }
}
