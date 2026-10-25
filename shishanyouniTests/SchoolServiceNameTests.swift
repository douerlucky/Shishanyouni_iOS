import Testing
@testable import shishanyouni

struct SchoolServiceNameTests
{
    @Test("认证入口与各功能的数据源使用各自的显示名称")
    func displaysServiceNamesByPurpose()
    {
        #expect(SchoolServiceName.unifiedIdentity == "统一身份认证（智慧狮山）")
        #expect(NanhuRunQuerySource.cas.title == "健康云")
        #expect(CourseQuerySource.cas.title == "本研教学一体化平台")
        #expect(ExamQuerySource.cas.title == "本研教学一体化平台")
        #expect(CurriculumImportSource.academic.title == "本研教学一体化平台")
        #expect(GradeQuerySource.teachingSystem.title == "教务系统")
    }

    @Test("显示名称变更不改变持久化的数据源标识")
    func keepsPersistedSourceIdentifiers()
    {
        #expect(NanhuRunQuerySource.cas.rawValue == "cas")
        #expect(CourseQuerySource.cas.rawValue == "cas")
        #expect(ExamQuerySource.cas.rawValue == "cas")
        #expect(CurriculumImportSource.academic.rawValue == "academic")
    }

    @Test("授权说明与实际功能对应，不再把认证协议写作数据源")
    func authorizationNamesMatchFeatures()
    {
        #expect(FeatureAuthorizationScope.grades.sourceDescription.contains("“教务系统”"))
        #expect(FeatureAuthorizationScope.allCourses.sourceDescription.contains("“本研教学一体化平台”"))
        #expect(FeatureAuthorizationScope.exams.sourceDescription.contains("“本研教学一体化平台”"))
        #expect(FeatureAuthorizationScope.nanhuRun.sourceDescription.contains("“健康云”"))
        #expect(FeatureAuthorizationScope.allCases.allSatisfy { !$0.sourceDescription.contains("CAS") })
    }
}
