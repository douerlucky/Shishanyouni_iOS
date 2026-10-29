import Foundation
import Testing
@testable import shishanyouni

/// 使用脱敏课表快照验证两类课程的导入契约，不登录或请求真实教务系统。
struct CurriculumImportTests
{
    private let fixture = #"""
    {
      "kbList": [
        {"jxb_id":"class-1","kch_id":"course-1","kcmc":"智能体技术与应用",
         "xqj":"1","jcs":"7-8","cdmc":"三教A101","xm":"测试教师",
         "khfsmc":"考查","zcd":"10-14周,16周"},
        {"jxb_id":"class-2","kcmc":"自然语言处理与知识发现",
         "xqj":"2","jc":"3-4节","cdmc":"三教A401","xm":"另一位教师",
         "khfsmc":"考试","zcd":"2-5周,7-9周"}
      ],
      "sjkList": [
        {"sfsjk":"1","sjkcgs":"毕业论文◇测试教师(共15周)/2-5周,7-17周",
         "qtkcgs":"毕业论文◇测试教师(共15周)/2-5周,7-17周/无"},
        {"sfsjk":"0","qtkcgs":"形势与政策（二）◇另一位教师（共18周）/2-19周/无"}
      ]
    }
    """#

    @Test("教务导入请求读取整学期并使用正确学期码")
    func requestUsesAcademicContract() throws
    {
        for (term, academicCode) in [("1", "3"), ("2", "12")]
        {
            let mappedTerm = AcademicCurriculumImporter.academicTermCode(from: term)
            #expect(mappedTerm == academicCode)
            let request = AcademicCurriculumAPI.makeRequest(cookie: "JSESSIONID=test", year: "2026", academicTerm: mappedTerm)
            #expect(request.url?.absoluteString == "http://byjxyt.hzau.edu.cn/kbcx/xskbcx_cxXsKb.html?gnmkdm=index")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Cookie") == "JSESSIONID=test")
            var form = URLComponents()
            form.percentEncodedQuery = String(decoding: try #require(request.httpBody), as: UTF8.self)
            let values = (form.queryItems ?? []).reduce(into: [String: String]()) { $0[$1.name] = $1.value }
            #expect(values == ["localeKey": "zh_CN", "xnm": "2026", "xqm": academicCode, "zs": ""])
        }
    }

    @Test("普通课程保留星期节次周次地点教师和考核方式")
    func importsScheduledCourses() throws
    {
        let courses = try AcademicCurriculumImporter.parseCourses(from: Data(fixture.utf8), year: "2026", term: "1")
        let course = try #require(courses.first)
        #expect(course.courseType == .regular)
        #expect(course.hasScheduledTime)
        #expect(course.day == 1)
        #expect(course.start == 7)
        #expect(course.step == 2)
        #expect(course.weekList == [10, 11, 12, 13, 14, 16])
        #expect(course.room == "三教A101")
        #expect(course.teacher == "测试教师")
        #expect(course.assessmentMethod == "考查")
        #expect(course.term == "2026-3")
        #expect(courses[1].start == 3)
        #expect(courses[1].step == 2)
        #expect(courses[1].weekList == [2, 3, 4, 5, 7, 8, 9])
    }

    @Test("实践课程与其他课程只保留周次，不伪造上课时间")
    func importsOtherCoursesWithoutTime() throws
    {
        let courses = try AcademicCurriculumImporter.parseCourses(from: Data(fixture.utf8), year: "2026", term: "1")
        let others = courses.filter { $0.courseType == .other }
        #expect(others.map(\.name) == ["毕业论文", "形势与政策（二）"])
        #expect(others.map(\.teacher) == ["测试教师", "另一位教师"])
        #expect(others[0].weekList == Array(2 ... 5) + Array(7 ... 17))
        #expect(others[1].weekList == Array(2 ... 19))
        #expect(others.allSatisfy { !$0.hasScheduledTime && $0.day == 0 && $0.start == 0 && $0.step == 0 })

        let saved = try JSONEncoder().encode(others)
        let restored = try JSONDecoder().decode([Course].self, from: saved)
        #expect(restored.map(\.courseType) == [.other, .other])
        #expect(restored.map(\.weekList) == others.map(\.weekList))
    }

    @Test("单双周和不连续周次能解析，损坏的范围不能静默变成单周")
    func parsesWeeksWithoutInventingDates()
    {
        #expect(CurriculumWeekParser.parse("1-8周(单),10-14周(双),17周") == [1, 3, 5, 7, 10, 12, 14, 17])
        #expect(CurriculumWeekParser.parse("2－5周，7周、9周") == [2, 3, 4, 5, 7, 9])
        #expect(CurriculumWeekParser.parse("1-abc周").isEmpty)
        #expect(CurriculumWeekParser.parse("2-1周").isEmpty)
        #expect(CurriculumWeekParser.parse("1-4周,未知周次").isEmpty)
    }

    @Test("其他课程不生成日历上课事件、不计入课时和占用时段")
    func unscheduledCoursesDoNotOccupyTime() throws
    {
        let others = try AcademicCurriculumImporter.parseCourses(from: Data(fixture.utf8), year: "2026", term: "1")
            .filter { $0.courseType == .other }
        let stats = CurriculumStatsView.compute(from: others, week: 3)
        #expect(stats.totalPeriods == 0)
        #expect(stats.stats.isEmpty)
        #expect(stats.freeSlots == 7 * CurriculumClassSchedule.displayOrder.count)
        #expect(CurriculumToSystemCalendar.eventDrafts(for: others, semesterStartDate: Date()).isEmpty)
    }

    @Test("重复响应去重且课程 ID 可稳定保存")
    func stableImportIdentity() throws
    {
        let first = try AcademicCurriculumImporter.parseCourses(from: Data(fixture.utf8), year: "2026", term: "1")
        let second = try AcademicCurriculumImporter.parseCourses(from: Data(fixture.utf8), year: "2026", term: "1")
        #expect(first.map(\.id) == second.map(\.id))
        #expect(Set(first.map(\.id)).count == 4)
        let repeated = #"{"kbList":[{"kcmc":"课程","xqj":"1","jcs":"1-2","zcd":"1-2周"},{"kcmc":"课程","xqj":"1","jcs":"1-2","zcd":"1-2周"}],"sjkList":[]}"#
        #expect(try AcademicCurriculumImporter.parseCourses(from: Data(repeated.utf8), year: "2026", term: "1").count == 1)
    }

    @Test("旧本地课表默认普通课程，不与同名其他课程合组")
    func legacyCourseTypeIsCompatible() throws
    {
        let legacy = #"{"id":"old","name":"课程","day":1,"start":1,"step":2,"weekList":[1,2],"colorRandom":1,"isManual":false}"#
        let course = try JSONDecoder().decode(Course.self, from: Data(legacy.utf8))
        #expect(course.courseType == .regular)
        var other = course
        other.courseType = .other
        #expect([course, other].groupedForCourseManagement().count == 2)
    }

    @Test("不相关响应或排课字段损坏时拒绝导入，避免清空已有课表")
    func rejectsInvalidResponse() throws
    {
        for json in [#"{"message":"login required"}"#,
                     #"{"kbList":[{"kcmc":"课程","xqj":"1","jcs":"1-abc","zcd":"1-2周"}]}"#]
        {
            #expect(throws: (any Error).self)
            {
                try AcademicCurriculumImporter.parseCourses(from: Data(json.utf8), year: "2026", term: "1")
            }
        }
        #expect(try AcademicCurriculumImporter.parseCourses(from: Data(#"{"kbList":[],"sjkList":[]}"#.utf8), year: "2026", term: "1").isEmpty)
    }
}
