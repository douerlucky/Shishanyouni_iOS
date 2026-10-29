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

extension Optional where Wrapped == String
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
