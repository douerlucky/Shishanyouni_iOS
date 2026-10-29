import Foundation

/// 查询当前学生已选主教学班对应的实验 / 子教学班。
///
/// 请求不是课表颜色页，而是选课模块的 `cxZkcZzxkYzb`：
/// `jxb_ids` 使用本次 ChoosedDisplay 返回的父教学班 ID，另外六个上下文字段
/// 从当前账号的 ChoosedDisplay / Index / Display 页面合并得到。任何字段缺失时
/// 都跳过该组，不猜测专业、年级、班级或选课规则。
final class SelectedCourseScheduleAPI
{
    static let shared = SelectedCourseScheduleAPI()

    private static let requiredContextFields = [
        "xkkz_id", "bklx_id", "kklxdm", "rlkz", "zyh_id", "njdm_id"
    ]

    private struct RequestGroup
    {
        let context: CourseSelectionContext
        var parentTeachingClassIDs: [String]
    }

    /// `pageContext` 是本次账号刚加载的选课页上下文；课程行自身返回的字段优先级更高。
    func fetchSchedules(
        cookie: String,
        courses: [SelectedCourse],
        pageContext: CourseSelectionContext = CourseSelectionContext()
    ) async throws -> [SelectedCourseScheduleEntry]
    {
        let groups = makeRequestGroups(courses: courses, pageContext: pageContext)
        guard !groups.isEmpty else
        {
            ChooseCourseDebug.warning("实验/子教学班补充未发送请求：没有完整的当前账号上下文")
            return []
        }

        var allEntries: [SelectedCourseScheduleEntry] = []
        var seenEntryIDs = Set<String>()
        var failures: [Error] = []
        var successfulGroupCount = 0

        // 按签名排序只为让 Debug 日志和抓包排查稳定；不改变任何服务端参数值。
        for key in groups.keys.sorted()
        {
            guard let group = groups[key] else { continue }
            let parameters = [
                ("jxb_ids", group.parentTeachingClassIDs.joined(separator: ",")),
                ("xkkz_id", group.context.value("xkkz_id")),
                ("bklx_id", group.context.value("bklx_id")),
                ("kklxdm", group.context.value("kklxdm")),
                ("rlkz", group.context.value("rlkz")),
                ("zyh_id", group.context.value("zyh_id")),
                ("njdm_id", group.context.value("njdm_id"))
            ]

            do
            {
                let (data, _) = try await CourseSelectionHTTP.send(
                    urlString: SchoolDirectAPI.selectedClassSchedulesURL,
                    method: "POST",
                    cookie: cookie,
                    parameters: parameters,
                    accept: "application/json, text/javascript, */*; q=0.01",
                    expectsJSON: true,
                    retryCount: 1
                )
                let entries = try SelectedCourseScheduleEntry.decodeEntries(from: data)
                successfulGroupCount += 1
                for entry in entries where seenEntryIDs.insert(entry.id).inserted
                {
                    allEntries.append(entry)
                }
                ChooseCourseDebug.info(
                    "实验/子教学班补充解析完成：本组主教学班=\(group.parentTeachingClassIDs.count)，实际排课=\(entries.count)"
                )
            }
            catch
            {
                failures.append(error)
                ChooseCourseDebug.warning("实验/子教学班补充本组读取失败：\(error.localizedDescription)")
            }
        }

        // 只有所有有效分组都失败才把错误交给调用方；部分分组成功时保留已拿到的安排。
        if successfulGroupCount == 0, let firstError = failures.first
        {
            throw firstError
        }
        ChooseCourseDebug.info(
            "实验/子教学班补充查询结束：分组成功=\(successfulGroupCount)/\(groups.count)，去重后=\(allEntries.count)"
        )
        return allEntries
    }

    private func makeRequestGroups(
        courses: [SelectedCourse],
        pageContext: CourseSelectionContext
    ) -> [String: RequestGroup]
    {
        var groups: [String: RequestGroup] = [:]

        for course in courses
        {
            let parentID = course.parentTeachingClassID
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !parentID.isEmpty, parentID != "0", parentID != "-1" else
            {
                ChooseCourseDebug.warning("跳过实验/子教学班补充：已选课程没有可用的父教学班 ID")
                continue
            }

            let context = resolvedContext(for: course, pageContext: pageContext)
            let missing = Self.requiredContextFields.filter { context.value($0).isEmpty }
            guard missing.isEmpty else
            {
                // 只列字段名；值可能包含学号、专业和短期选课凭据，绝不写入日志。
                ChooseCourseDebug.context(
                    "实验/子教学班补充上下文",
                    values: context.values,
                    requiredFields: Self.requiredContextFields
                )
                ChooseCourseDebug.warning(
                    "跳过实验/子教学班补充：当前课程缺少 \(missing.joined(separator: "、"))"
                )
                continue
            }

            let key = Self.requiredContextFields.map { context.value($0) }.joined(separator: "\u{1F}")
            if var group = groups[key]
            {
                if !group.parentTeachingClassIDs.contains(parentID)
                {
                    group.parentTeachingClassIDs.append(parentID)
                    groups[key] = group
                }
            }
            else
            {
                groups[key] = RequestGroup(context: context, parentTeachingClassIDs: [parentID])
            }
        }
        return groups
    }

    /// 课程行字段覆盖页面兜底字段；只有行字段缺失时，才从当前页面的学生/培养方案
    /// 源字段推导 `njdm_id` / `zyh_id`。显式返回的值永远不会被覆盖。
    private func resolvedContext(
        for course: SelectedCourse,
        pageContext: CourseSelectionContext
    ) -> CourseSelectionContext
    {
        var values = pageContext.values
        for (rawKey, rawValue) in course.selectionContext.values
        {
            let key = rawKey == "jg_id_1" ? "jg_id" : rawKey
            let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty
            {
                values[key] = value
            }
        }

        // 只有 ChoosedDisplay 这一行明确返回的 njdm_id / zyh_id 才算“显式值”。
        // pageContext 里的同名字段可能是默认主修页按另一种 rwlx/kklxdm 推导出的
        // 结果，不能把它误当成所有课程类别都通用的个人参数。
        let explicitGrade = course.selectionContext.value("njdm_id")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let explicitMajor = course.selectionContext.value("zyh_id")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var resolved = CourseSelectionContext(values: values).applyingFrontendRuleValues()
        // applyingFrontendRuleValues 会依据合并后的课程类型选择 s_* / t_*；明确的
        // ChoosedDisplay 行字段优先级更高，最后再覆盖回来。
        if !explicitGrade.isEmpty { resolved.values["njdm_id"] = explicitGrade }
        if !explicitMajor.isEmpty { resolved.values["zyh_id"] = explicitMajor }
        return resolved
    }
}
