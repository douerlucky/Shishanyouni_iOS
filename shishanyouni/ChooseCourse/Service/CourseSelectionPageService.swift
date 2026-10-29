import Foundation
import SwiftUI

/// 按网页真实步骤加载 Index 与 Display 片段，得到当前会话的选课上下文。
enum CourseSelectionPageService
{
    static func load(
        cookie: String,
        semester: SelectedCourseSemester,
        category: CourseCatalogCategory? = nil
    ) async throws -> CourseSelectionContext
    {
        ChooseCourseDebug.info("开始加载选课页上下文：\(semester.displayName)")
        let indexData = try await CourseSelectionAPI.request(.index, cookie: cookie)
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
        let displayData = try await CourseSelectionAPI.request(.display, cookie: cookie, parameters: displayParameters)
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
