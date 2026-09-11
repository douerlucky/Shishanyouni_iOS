//
//  CurriculumAssessmentTests.swift
//  shishanyouniTests
//
//  课程考核方式接口的本地解析测试。
//  这些测试使用脱敏 JSON，不会登录教务系统，也不会向真实接口发请求。
//

import Foundation
import Testing
@testable import shishanyouni

struct CurriculumAssessmentTests
{
    @Test("App 学期码能映射到教务课表学期码")
    func mapsAcademicTermCodes() {
        // 狮山接口使用 1/2，教务课表接口使用 3/12。
        #expect(CurriculumAssessmentService.academicTermCode(from: "1") == "3")
        #expect(CurriculumAssessmentService.academicTermCode(from: "2") == "12")
        // 未知值按秋季学期处理，保持与线上兼容逻辑一致。
        #expect(CurriculumAssessmentService.academicTermCode(from: "") == "3")
    }

    @Test("解析考试考查并忽略未安排")
    func parsesAssessmentMethods() throws {
        let json = """
        {
          "kbList": [
            {
              "kcmc": "操作系统原理",
              "jxbmc": "操作系统原理-0001A",
              "khfsmc": "未安排"
            },
            {
              "kcmc": "操作系统原理",
              "jxbmc": "操作系统原理-0001",
              "khfsmc": "考试"
            },
            {
              "kcmc": "信息安全",
              "jxbmc": "信息安全-0002",
              "khfsmc": "考查"
            },
            {
              "kcmc": "实验课程",
              "jxbmc": "实验课程-0001C",
              "khfsmc": "未安排"
            }
          ]
        }
        """

        let result = try CurriculumAssessmentService.parseAssessmentMethods(from: Data(json.utf8))

        // 理论班优先于同名实验班，因此操作系统原理仍然显示“考试”。
        #expect(result["操作系统原理"] == "考试")
        #expect(result["信息安全"] == "考查")
        #expect(result["实验课程"] == nil)
    }

    @Test("旧课表没有 khfsmc 时仍然可以解码")
    func decodesLegacyTimetableWithoutAssessmentMethod() throws {
        let json = """
        {
          "name": "旧课程",
          "day": 1,
          "weekList": [1, 2],
          "start": 1,
          "step": 2
        }
        """

        let model = try JSONDecoder().decode(TimetableModel.self, from: Data(json.utf8))

        #expect(model.name == "旧课程")
        #expect(model.assessmentMethod == nil)
        #expect(model.weekList == [1, 2])
    }

    @Test("已保存的旧 Course 数据没有考核方式时仍然可以解码")
    func decodesLegacyCourseWithoutAssessmentMethod() throws {
        let json = """
        {
          "id": "2026-1_day1_s1_n2_w1-2x2_旧课程",
          "name": "旧课程",
          "day": 1,
          "start": 1,
          "step": 2,
          "room": "一教A101",
          "teacher": "老师",
          "weekList": [1, 2],
          "weeks": "1-2周",
          "term": "2026-1",
          "colorRandom": 1,
          "customColorHex": null,
          "isManual": false
        }
        """

        let course = try JSONDecoder().decode(Course.self, from: Data(json.utf8))

        #expect(course.name == "旧课程")
        #expect(course.assessmentMethod == nil)
    }

    @Test("课表日历标题按开学日期区分秋季和春季")
    func calendarTitlesUseAcademicYearAndSemester() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!

        let autumnStart = calendar.date(from: DateComponents(year: 2026, month: 8, day: 31))!
        let springStart = calendar.date(from: DateComponents(year: 2027, month: 2, day: 22))!

        #expect(
            CurriculumToSystemCalendar.calendarTitle(for: autumnStart)
                == "狮山有你 · 2026-2027 秋季课表"
        )
        #expect(
            CurriculumToSystemCalendar.calendarTitle(for: springStart)
                == "狮山有你 · 2026-2027 春季课表"
        )
    }

    @Test("课程周次会展开为真实日期和节次时间，并跳过已结束课程")
    func expandsCourseWeeksAndSkipsFinishedClasses() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!

        let semesterStart = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 31)
        )!
        let course = Course.createManualCourse(
            name: "测试课程",
            weekday: 1,
            startPeriod: 1,
            endPeriod: 2,
            weeks: [1, 2]
        )

        let beforeFirstClass = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 30, hour: 0)
        )!
        let drafts = CurriculumToSystemCalendar.eventDrafts(
            for: [course],
            semesterStartDate: semesterStart,
            now: beforeFirstClass,
            calendar: calendar
        )

        #expect(drafts.count == 2)
        #expect(drafts[0].week == 1)
        #expect(drafts[1].week == 2)

        let firstComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: drafts[0].startDate
        )
        #expect(firstComponents.year == 2026)
        #expect(firstComponents.month == 8)
        #expect(firstComponents.day == 31)
        #expect(firstComponents.hour == 8)
        #expect(firstComponents.minute == 0)

        let afterFirstClass = calendar.date(
            from: DateComponents(year: 2026, month: 9, day: 1, hour: 10)
        )!
        let remainingDrafts = CurriculumToSystemCalendar.eventDrafts(
            for: [course],
            semesterStartDate: semesterStart,
            now: afterFirstClass,
            calendar: calendar
        )

        #expect(remainingDrafts.count == 1)
        #expect(remainingDrafts.first?.week == 2)
    }
}
