import Foundation
import SwiftUI

/// 模仿正方页面的只读课程检索链路。
final class CourseCatalogService
{
    static let shared = CourseCatalogService()

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
        let pageContext = try await CourseSelectionPageService.load(cookie: cookie, semester: semester)
        var parameters = catalogParameters(context: pageContext, rangeStart: 1, rangeEnd: 10)
        parameters.append(contentsOf: searchBoxParameters(for: normalizedKeyword))

        let data = try await CourseSelectionAPI.request(.catalog, cookie: cookie, parameters: parameters)
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
        var categoryContext = try await CourseSelectionPageService.load(
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
        let data = try await CourseSelectionAPI.request(.catalog, cookie: cookie, parameters: parameters)
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

    /// 只在课程存在多层教学班时调用。单层课程会直接由 CourseMutationService 进入确认步骤。
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
        let dialogData = try await CourseSelectionAPI.request(.childDialog, cookie: cookie, parameters: dialogParameters)
        let dialogHTML = String(data: dialogData, encoding: .utf8) ?? ""
        let dialogContext = course.context
            .merged(with: CourseSelectionHTML.context(from: dialogHTML))
            .applying(semester)
        ChooseCourseDebug.context("子教学班弹窗", values: dialogContext.values)

        var displayParameters = CourseSelectionContext.childDisplayFields.map { ($0, dialogContext.value($0)) }
        displayParameters.append(("jxb_id", course.selectionToken))
        displayParameters.append(("jxbzls", String(course.classLevels)))
        displayParameters.append(("syqz", dialogContext.value("syqz").isEmpty ? "100" : dialogContext.value("syqz")))
        let displayData = try await CourseSelectionAPI.request(.childClasses, cookie: cookie, parameters: displayParameters)
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
            let data = try await CourseSelectionAPI.request(.parentClasses, cookie: cookie, parameters: parameters)
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
