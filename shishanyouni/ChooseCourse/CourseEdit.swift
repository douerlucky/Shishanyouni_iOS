//
//  CourseEdit.swift
//  shishanyouni
//
//  最终选课与退选写操作。每次写请求都禁用网络自动重试，并在服务端提示成功后
//  再读取一次已选列表核验，避免把 HTTP 200 误认为“已经选上”。
//

import Foundation

enum CourseMutationStatus
{
    case success
    case rejected
    case unknown
}

struct CourseMutationResult
{
    let status: CourseMutationStatus
    let message: String
    let verified: Bool?

    var succeeded: Bool { status == .success && verified == true }
}

/// 选课前的只读准备结果。单层课程直接进入确认；多层课程必须先让用户选择子教学班。
enum CourseSelectionPreparation
{
    case direct(CourseChildClass)
    case needsChildSelection([CourseChildClass])
}

/// 选、退课的唯一写入口。
///
/// 所有 token 都来自同一个内存中的查询会话；这里不接受课程号反推 token，也不会保存它们。
final class CourseEdit
{
    static let shared = CourseEdit()

    func prepareSelection(
        for course: CourseSearchResult,
        cookie: String,
        semester: SelectedCourseSemester
    ) async throws -> CourseSelectionPreparation
    {
        ChooseCourseDebug.info("准备选课：课程号=\(course.courseCode)，教学班层级=\(course.classLevels)")
        guard course.hasCurrentSelectionParameters else
        {
            ChooseCourseDebug.error("准备选课停止：课程没有当前会话教学班参数")
            throw CourseSelectionServiceError.missingCurrentParameters
        }

        if course.requiresChildClass
        {
            ChooseCourseDebug.info("课程需要选择子教学班，开始读取子班列表")
            let currentSemester = course.context.resolvedSemester(fallback: semester)
            let children = try await SearchCourse.shared.loadChildClasses(
                for: course,
                cookie: cookie,
                semester: currentSemester
            )
            ChooseCourseDebug.info("子教学班准备完成：\(children.count) 个可选项，即将展示 Sheet")
            return .needsChildSelection(children)
        }
        ChooseCourseDebug.info("课程无需子教学班，直接进入选课确认")
        return .direct(SearchCourse.directClass(for: course))
    }

    /// 在用户明确确认后，仅发送一次 xkBc 请求。
    func select(
        course: CourseSearchResult,
        teachingClass: CourseChildClass,
        cookie: String,
        semester: SelectedCourseSemester
    ) async throws -> CourseMutationResult
    {
        ChooseCourseDebug.info("用户已确认选课：课程号=\(course.courseCode)，准备进行一次性提交")
        guard teachingClass.canSelect else
        {
            ChooseCourseDebug.error("选课停止：选择的教学班没有服务端临时参数")
            throw CourseSelectionServiceError.missingCurrentParameters
        }

        // 课程目录携带的 Index / Display 上下文优先于设备日期，防止不同账号的
        // 选课开放学期不同却仍向错误学期读取或提交。
        let currentSemester = course.context.resolvedSemester(fallback: semester)

        // 最终写入前重新读取一次已选课程，防止用户重复点击或状态已在网页端改变。
        let selectedBefore = try await SelectedCourseQuery.shared.fetchSelectedCourses(
            cookie: cookie,
            semester: currentSemester
        )
        ChooseCourseDebug.info("选课前已选列表核验：当前 \(selectedBefore.count) 门")
        if contains(course: course, in: selectedBefore)
        {
            ChooseCourseDebug.warning("选课未提交：该课程已在已选列表中")
            return CourseMutationResult(
                status: .rejected,
                // 与正方网页保持一致，避免用户看到内部“预检”术语；日志仍会记录本次未提交。
                message: "一门课程最多可选1个志愿！",
                verified: true
            )
        }

        var context = course.context.applying(currentSemester)
        // 这两个默认值来自当前正方前端的最终提交逻辑；页面若提供其它值则始终尊重页面值。
        if context.value("qz").isEmpty { context.values["qz"] = "0" }
        if context.value("sxbj").isEmpty { context.values["sxbj"] = "1" }

        let missing = CourseSelectionContext.selectionRequiredFields.filter { context.value($0).isEmpty }
        guard missing.isEmpty else
        {
            ChooseCourseDebug.error("选课停止：最终提交缺少上下文字段 [\(missing.joined(separator: ","))]")
            throw CourseSelectionServiceError.missingContext(missing)
        }
        ChooseCourseDebug.context("选课最终提交", values: context.values, requiredFields: CourseSelectionContext.selectionRequiredFields)

        var parameters: [(String, String)] = [
            ("kcmc", selectionCaption(for: course)),
            ("kch_id", course.courseID),
            ("jxb_ids", teachingClass.selectionTokens.joined(separator: ","))
        ]
        parameters.append(contentsOf: CourseSelectionContext.selectionRequiredFields.map { ($0, context.value($0)) })

        // retryCount 为 0：即使超时也绝不自动再发一次可能改变课表的请求。
        let (data, _) = try await CourseSelectionHTTP.send(
            urlString: CourseSelectionEndpoint.select,
            method: "POST",
            cookie: cookie,
            parameters: parameters,
            expectsJSON: true,
            retryCount: 0
        )
        let serverResult = mutationResult(from: data, successMarkers: ["选课成功", "已选上"])
        ChooseCourseDebug.info("选课接口业务结果：\(debugStatus(serverResult.status))；\(serverResult.message)")
        guard serverResult.status == .success else { return serverResult }

        // 正方的 HTTP 200 只说明已处理请求，因此必须再核验一次；核验失败绝不重复提交。
        do
        {
            let selectedAfter = try await SelectedCourseQuery.shared.fetchSelectedCourses(
                cookie: cookie,
                semester: currentSemester
            )
            if contains(course: course, in: selectedAfter)
            {
                ChooseCourseDebug.info("选课结果核验成功：已选列表现有 \(selectedAfter.count) 门")
                return CourseMutationResult(
                    status: .success,
                    message: "\(serverResult.message) 已在已选课程中核验成功。",
                    verified: true
                )
            }
            ChooseCourseDebug.warning("选课接口称成功，但已选列表未出现目标课程")
            return CourseMutationResult(
                status: .unknown,
                message: "\(serverResult.message) 但已选列表暂未出现该课程，请到教务网页确认；不会自动重复提交。",
                verified: false
            )
        }
        catch
        {
            ChooseCourseDebug.warning("选课接口称成功，但后续已选列表核验失败：\(error.localizedDescription)")
            return CourseMutationResult(
                status: .unknown,
                message: "\(serverResult.message) 但暂时无法读取已选列表核验，请手动刷新确认；不会自动重复提交。",
                verified: nil
            )
        }
    }

    /// 退选时不复用屏幕上旧课程的 token，而是先刷新当前已选列表再做规则检查。
    func drop(
        course: SelectedCourse,
        cookie: String,
        semester: SelectedCourseSemester
    ) async throws -> CourseMutationResult
    {
        ChooseCourseDebug.info("用户已确认退选：课程号=\(course.courseCode ?? course.courseID)")
        let pageContext = try await CourseSelectionPageLoader.load(cookie: cookie, semester: semester)
        let currentSemester = pageContext.resolvedSemester(fallback: semester)
        let selectedCourses = try await SelectedCourseQuery.shared.fetchSelectedCourses(
            cookie: cookie,
            semester: currentSemester
        )
        guard let current = selectedCourses.first(where: { matches($0, course) }) else
        {
            ChooseCourseDebug.warning("退选未提交：目标课程不在刚刷新的已选列表中")
            return CourseMutationResult(
                status: .rejected,
                message: "该课程已不在已选列表中，本次没有提交退选请求。",
                verified: true
            )
        }
        guard current.dropAllowed else
        {
            ChooseCourseDebug.warning("退选未提交：教务系统当前禁止退选")
            return CourseMutationResult(
                status: .rejected,
                message: "教务系统当前不允许退选这门课程，本次没有提交退选请求。",
                verified: false
            )
        }
        guard !current.courseID.isEmpty, let firstToken = current.selectionTokens.first else
        {
            ChooseCourseDebug.error("退选停止：最新已选记录缺少临时参数")
            throw CourseSelectionServiceError.missingCurrentParameters
        }

        let context = pageContext
            .merged(with: current.selectionContext)
            .applying(currentSemester)
        let checkParameters = [
            ("xkkz_id", context.value("xkkz_id")),
            ("jxb_id", firstToken),
            ("kch_id", current.courseID),
            ("xnm", context.value("xkxnm")),
            ("xqm", context.value("xkxqm"))
        ]
        let missingCheckFields = checkParameters.filter { $0.1.isEmpty }.map(\.0)
        guard missingCheckFields.isEmpty else
        {
            ChooseCourseDebug.error("退选规则检查停止：缺少字段 [\(missingCheckFields.joined(separator: ","))]")
            throw CourseSelectionServiceError.missingContext(missingCheckFields)
        }

        let (checkData, _) = try await CourseSelectionHTTP.send(
            urlString: CourseSelectionEndpoint.dropCheck,
            method: "POST",
            cookie: cookie,
            parameters: checkParameters,
            expectsJSON: true,
            retryCount: 1
        )
        let checkDecision = dropCheckDecision(from: checkData)
        ChooseCourseDebug.info("退选规则检查解析：\(checkDecision.logName)")
        guard checkDecision == .allowed else
        {
            ChooseCourseDebug.warning("退选规则检查未通过，未发送退选写请求")
            let message: String
            switch checkDecision
            {
            case .denied:
                message = "教务系统当前不允许退选这门课程，本次没有提交退选请求。"
            case .unknown:
                message = "教务系统返回了无法识别的退选规则结果，本次没有提交请求；请刷新后重试。"
            case .allowed:
                // 仅为穷尽枚举分支；不会进入这里。
                message = "教务系统当前不允许退选这门课程，本次没有提交退选请求。"
            }
            return CourseMutationResult(
                status: .rejected,
                message: message,
                verified: false
            )
        }

        let dropFields = ["rwlx", "rlkz", "rlzlkz", "xklc", "xkxnm", "xkxqm"]
        let missingDropFields = dropFields.filter { context.value($0).isEmpty }
        guard missingDropFields.isEmpty else
        {
            ChooseCourseDebug.error("退选停止：最终提交缺少字段 [\(missingDropFields.joined(separator: ","))]")
            throw CourseSelectionServiceError.missingContext(missingDropFields)
        }
        ChooseCourseDebug.context("退选最终提交", values: context.values, requiredFields: dropFields)
        var dropParameters: [(String, String)] = [
            ("kch_id", current.courseID),
            ("kcmc", selectionCaption(for: current)),
            ("jxb_ids", current.selectionTokens.joined(separator: ","))
        ]
        dropParameters.append(contentsOf: dropFields.map { ($0, context.value($0)) })
        dropParameters.append(("txbsfrl", context.value("txbsfrl").isEmpty ? "0" : context.value("txbsfrl")))

        let (dropData, _) = try await CourseSelectionHTTP.send(
            urlString: CourseSelectionEndpoint.drop,
            method: "POST",
            cookie: cookie,
            parameters: dropParameters,
            expectsJSON: true,
            retryCount: 0
        )
        let serverResult = mutationResult(from: dropData, successMarkers: ["退课成功", "退选成功"])
        ChooseCourseDebug.info("退选接口业务结果：\(debugStatus(serverResult.status))；\(serverResult.message)")
        guard serverResult.status == .success else { return serverResult }

        // 网页会在退课后同步志愿顺序；同步失败不掩盖已经提交的退课结果。
        let synchronizationNote: String
        do
        {
            let (syncData, _) = try await CourseSelectionHTTP.send(
                urlString: CourseSelectionEndpoint.preferenceSync,
                method: "POST",
                cookie: cookie,
                parameters: [("zypxs", ""), ("jxb_ids", "")],
                expectsJSON: true,
                retryCount: 0
            )
            let syncResult = mutationResult(from: syncData, successMarkers: ["成功"])
            synchronizationNote = syncResult.status == .success ? " 志愿顺序已同步。" : " 志愿顺序同步未返回明确成功，请到网页确认。"
            ChooseCourseDebug.info("退选后志愿顺序同步：\(debugStatus(syncResult.status))")
        }
        catch
        {
            synchronizationNote = " 志愿顺序同步失败，请到网页确认。"
            ChooseCourseDebug.warning("退选后志愿顺序同步请求失败：\(error.localizedDescription)")
        }

        do
        {
            let selectedAfter = try await SelectedCourseQuery.shared.fetchSelectedCourses(
                cookie: cookie,
                semester: currentSemester
            )
            if !selectedAfter.contains(where: { matches($0, current) })
            {
                ChooseCourseDebug.info("退选结果核验成功：目标课程已从已选列表移除")
                return CourseMutationResult(
                    status: .success,
                    message: "\(serverResult.message) 已从已选课程中核验移除。\(synchronizationNote)",
                    verified: true
                )
            }
            ChooseCourseDebug.warning("退选接口称成功，但最新已选列表仍存在该课程")
            return CourseMutationResult(
                status: .unknown,
                message: "\(serverResult.message) 但最新已选列表仍包含该课程，请到教务网页确认；不会自动重复提交。\(synchronizationNote)",
                verified: false
            )
        }
        catch
        {
            ChooseCourseDebug.warning("退选接口称成功，但已选列表核验失败：\(error.localizedDescription)")
            return CourseMutationResult(
                status: .unknown,
                message: "\(serverResult.message) 但暂时无法核验已选列表，请手动刷新确认；不会自动重复提交。\(synchronizationNote)",
                verified: nil
            )
        }
    }

    private func contains(course: CourseSearchResult, in selectedCourses: [SelectedCourse]) -> Bool
    {
        selectedCourses.contains
        {
            (!$0.courseID.isEmpty && $0.courseID == course.courseID)
                || (!$0.courseCode.orEmpty.isEmpty && $0.courseCode == course.courseCode)
        }
    }

    private func debugStatus(_ status: CourseMutationStatus) -> String
    {
        switch status
        {
        case .success: return "成功"
        case .rejected: return "被教务系统拒绝"
        case .unknown: return "结果待确认"
        }
    }

    private func matches(_ lhs: SelectedCourse, _ rhs: SelectedCourse) -> Bool
    {
        (!lhs.courseID.isEmpty && lhs.courseID == rhs.courseID)
            || (!lhs.courseCode.orEmpty.isEmpty && lhs.courseCode == rhs.courseCode)
    }

    private func selectionCaption(for course: CourseSearchResult) -> String
    {
        let rawCaption = course.selectionCaption.ifEmpty(course.courseName)
        let base = rawCaption.hasPrefix("(") ? rawCaption : "(\(course.courseCode))\(rawCaption)"
        guard !base.contains("简介"), !course.credit.isEmpty else { return base }
        return "\(base) 简介 - \(course.credit) 学分"
    }

    private func selectionCaption(for course: SelectedCourse) -> String
    {
        let rawCaption = course.selectionCaption.ifEmpty(course.courseName)
        let base = rawCaption.hasPrefix("(") ? rawCaption : "(\(course.courseCode ?? course.courseID))\(rawCaption)"
        guard !base.contains("简介"), let credit = course.displayCredit, !credit.isEmpty else { return base }
        return "\(base) 简介 - \(credit) 学分"
    }

    private func mutationResult(from data: Data, successMarkers: [String]) -> CourseMutationResult
    {
        // 正方有些版本把业务结果直接返回为顶层数字/字符串（例如 `1\r\n`）。
        // 允许 JSON fragment，避免把实际成功误报成“结果待确认”。
        let payload = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])

        // 业务 flag 比 HTTP 200 更可靠。特别是 `{flag:"-1", msg:"0,<教学班ID>,<人数>"}`
        // 这种响应，HTTP 层成功但实际表示满班被拒绝，不能落入“结果待确认”。
        if let rejectionMessage = explicitRejectionMessage(from: payload, rawData: data)
        {
            return CourseMutationResult(status: .rejected, message: rejectionMessage, verified: false)
        }

        let message = sanitizedMessage(from: payload, rawData: data)
        let lowered = message.lowercased()
        let negativeMarkers = [
            "失败", "错误", "无余量", "不可选", "已满", "冲突", "不成功", "未选", "拒绝",
            // 不把“已选”单独作为失败词，避免误伤“已选上”；下面这些是正方常见的单志愿限制文案。
            "最多可选", "只能选一个", "不可重复", "重复选择", "已在已选列表"
        ]
        if negativeMarkers.contains(where: { lowered.contains($0) })
        {
            return CourseMutationResult(status: .rejected, message: message, verified: false)
        }
        if responseIndicatesSuccess(payload) || successMarkers.contains(where: { message.contains($0) })
        {
            return CourseMutationResult(status: .success, message: message, verified: nil)
        }
        return CourseMutationResult(
            status: .unknown,
            message: "\(message) 教务系统没有给出明确成功提示，请手动刷新确认；不会自动重复提交。",
            verified: nil
        )
    }

    private enum DropCheckDecision: Equatable
    {
        case allowed
        case denied
        case unknown

        var logName: String
        {
            switch self
            {
            case .allowed: return "允许（服务端标量/标记=真）"
            case .denied: return "拒绝（服务端标量/标记=假）"
            case .unknown: return "无法识别"
            }
        }
    }

    /// 退选规则接口有时返回 `1\r\n` 这类顶层 JSON 标量。
    /// `JSONSerialization` 不带 `.fragmentsAllowed` 时会把它误判为非法 JSON，
    /// 进而阻止本来允许的退选；这里只接受明确的允许/拒绝标记，未知值仍然拦截写请求。
    private func dropCheckDecision(from data: Data) -> DropCheckDecision
    {
        if let payload = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
           let decision = dropCheckDecision(from: payload)
        {
            return decision
        }

        // 少数旧版本直接返回纯文本而不是 JSON；只识别完整的安全标量，
        // 不用“非空”或模糊包含来绕过规则检查。
        let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        return Self.dropCheckDecision(for: text) ?? .unknown
    }

    private func dropCheckDecision(from payload: Any) -> DropCheckDecision?
    {
        if let value = payload as? Bool { return value ? .allowed : .denied }
        if let value = payload as? NSNumber
        {
            // JSONSerialization 用 NSNumber 表示数字和布尔；布尔已在上面处理。
            return value.intValue == 1 ? .allowed : value.intValue == 0 ? .denied : nil
        }
        if let value = payload as? String
        {
            return Self.dropCheckDecision(for: value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        }
        if let values = payload as? [Any]
        {
            // 接口偶尔把标量包在单元素数组里，例如 `[1]`；只采纳唯一明确结果。
            guard values.count == 1, let first = values.first else { return nil }
            return dropCheckDecision(from: first)
        }
        if let object = payload as? [String: Any]
        {
            // 优先读取业务标记；`success=false` 必须明确视为拒绝。
            for key in ["success", "flag", "allow", "allowed", "canDrop", "sfktk", "status", "code"]
            {
                if let value = object[key], let decision = dropCheckDecision(from: value)
                {
                    return decision
                }
            }
            // 某些版本把结果再包在 data/result 中。
            for key in ["data", "result"]
            {
                if let value = object[key], let decision = dropCheckDecision(from: value)
                {
                    return decision
                }
            }
        }
        return nil
    }

    private static func dropCheckDecision(for value: String) -> DropCheckDecision?
    {
        switch value
        {
        case "1", "true", "yes", "y", "success", "ok", "allow", "allowed":
            return .allowed
        case "0", "false", "no", "n", "fail", "failed", "error", "deny", "denied":
            return .denied
        default:
            return nil
        }
    }

    private func responseIndicatesSuccess(_ payload: Any?) -> Bool
    {
        if let object = payload as? [String: Any]
        {
            if let success = object["success"] as? Bool, success { return true }
            return ["1", "true", "success", "ok"].contains(scalarString(object["flag"]).lowercased())
        }
        if let value = payload as? Bool { return value }
        if let value = payload as? NSNumber { return value.intValue == 1 }
        if let value = payload as? String
        {
            return ["1", "true", "success", "ok"].contains(value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        }
        if let values = payload as? [Any], values.count == 1
        {
            return responseIndicatesSuccess(values.first)
        }
        return false
    }

    /// 正方的最终写接口用 `flag` 表示业务结果；`-1`、`0` 并不意味着网络失败，
    /// 而是服务端已经拒绝了本次选课/退选。这里单独识别，避免把协议值显示给用户。
    private func responseIndicatesRejection(_ payload: Any?) -> Bool
    {
        if let object = payload as? [String: Any]
        {
            if let success = object["success"] as? Bool, !success { return true }
            return isRejectedBusinessFlag(scalarString(object["flag"]))
        }
        if let value = payload as? Bool { return !value }
        if let value = payload as? NSNumber { return value.intValue == 0 || value.intValue == -1 }
        if let value = payload as? String { return isRejectedBusinessFlag(value) }
        if let values = payload as? [Any], values.count == 1
        {
            return responseIndicatesRejection(values.first)
        }
        return false
    }

    private func isRejectedBusinessFlag(_ rawValue: String) -> Bool
    {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        {
        case "-1", "0", "false", "fail", "failed", "error", "reject", "rejected", "deny", "denied":
            return true
        default:
            return false
        }
    }

    /// 保留服务端的中文业务原因；只有像 `0,<ID>,59` / `1,<ID>,61` 这样的机器协议才翻译成本地文案。
    /// 这样“一个课程只能报一个志愿”等服务端规则能原样出现在系统 Alert 中。
    private func explicitRejectionMessage(from payload: Any?, rawData: Data) -> String?
    {
        guard responseIndicatesRejection(payload) else { return nil }

        if let object = payload as? [String: Any]
        {
            let rawMessage = rawMessage(in: object)
            if isOpaqueCapacityRejection(rawMessage)
            {
                return "该教学班已无余量，不可选！"
            }
        }

        return sanitizedMessage(from: payload, rawData: rawData)
    }

    /// 示例中的 `0,52F32D19E2054082E065000000000001,59` 或
    /// `1,532763208783A95EE065000000000001,61` 不可直接展示：
    /// 中间是教学班 ID，末尾是内部人数数据。该格式配合拒绝 flag 即表示无余量。
    private func isOpaqueCapacityRejection(_ value: String) -> Bool
    {
        value.range(
            of: #"^\s*[01]\s*,\s*[0-9A-Fa-f]{16,}\s*,\s*\d+\s*$"#,
            options: .regularExpression
        ) != nil
    }

    /// 协议字段或 token 不是面向用户的结果说明。返回泛化文案既避免泄露临时参数，
    /// 也不会让用户把 `0,<ID>,59` 一类内容误认为成功。
    private func isOpaqueSelectionProtocol(_ value: String) -> Bool
    {
        value.range(
            of: #"^\s*(?:-?\d+|[A-Za-z]+)(?:\s*,\s*(?:[0-9A-Fa-f]{16,}|-?\d+))+\s*$"#,
            options: .regularExpression
        ) != nil
    }

    private func rawMessage(in object: [String: Any]) -> String
    {
        for key in ["msg", "message", "error", "detail", "data"]
        {
            let value = scalarString(object[key])
            if !value.isEmpty { return value }
        }
        return ""
    }

    private func sanitizedMessage(from payload: Any?, rawData: Data) -> String
    {
        var message = ""
        if let object = payload as? [String: Any]
        {
            message = rawMessage(in: object)
            // `{ "flag": "1" }` 这类响应只有机器状态，没有可展示文字；不能把
            // 原始 JSON 透传给用户。成功和明确失败都转成可读的本地文案。
            if message.isEmpty
            {
                if responseIndicatesSuccess(object)
                {
                    message = "服务器已受理本次请求。"
                }
                else if responseIndicatesRejection(object)
                {
                    message = "教务系统拒绝了本次请求。"
                }
                else if object["flag"] != nil || object["success"] != nil || object["status"] != nil
                {
                    message = "教务系统拒绝了本次请求。"
                }
            }
        }
        else if let value = payload as? String
        {
            message = value
        }
        if message.isEmpty
        {
            message = String(data: rawData, encoding: .utf8) ?? "服务器返回了空响应。"
        }
        message = message
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if message.isEmpty || ["1", "true", "success", "ok"].contains(message.lowercased())
        {
            message = "服务器已受理本次请求。"
        }
        // 顶层 `-1` / `0` / `false` 也是机器状态，不应把它们原样放进 Alert。
        if isRejectedBusinessFlag(message)
        {
            return "教务系统拒绝了本次请求。"
        }
        if isOpaqueSelectionProtocol(message)
        {
            return "教务系统已处理本次请求，但没有提供可展示的说明。"
        }
        // 教学班临时 token 和教学班 ID 都不是用户需要的信息，绝不在 Alert 中回显。
        return message.replacingOccurrences(of: #"(?i)(?<![0-9a-f])[0-9a-f]{24,}(?![0-9a-f])"#, with: "<已隐藏>", options: .regularExpression)
    }

    private func scalarString(_ value: Any?) -> String
    {
        switch value
        {
        case let string as String:
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        case let number as NSNumber:
            return number.stringValue
        default:
            return ""
        }
    }
}

private extension Optional where Wrapped == String
{
    var orEmpty: String { self ?? "" }
}
