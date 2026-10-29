import Testing
@testable import shishanyouni

struct CourseSelectionAPIContractTests
{
    @Test("选课、退课与志愿顺序同步禁止自动重发")
    func mutationsNeverRetry()
    {
        for endpoint in [CourseSelectionAPI.Endpoint.submit, .drop, .preferenceSync]
        {
            #expect(endpoint.retryCount == 0)
            #expect(endpoint.method == "POST")
            #expect(endpoint.expectsJSON)
        }
    }

    @Test("只读选课请求保持原有的一次重试")
    func readRequestsKeepTheirRetryPolicy()
    {
        for endpoint in [CourseSelectionAPI.Endpoint.index, .display, .catalog, .parentClasses, .childDialog, .childClasses, .dropCheck]
        {
            #expect(endpoint.retryCount == 1)
        }
        #expect(CourseSelectionAPI.Endpoint.index.method == "GET")
        #expect(CourseSelectionAPI.Endpoint.catalog.method == "POST")
    }

    @Test("页面和 JSON 接口不混用响应格式")
    func requestFormatsStaySeparate()
    {
        #expect(!CourseSelectionAPI.Endpoint.index.expectsJSON)
        #expect(!CourseSelectionAPI.Endpoint.display.expectsJSON)
        #expect(!CourseSelectionAPI.Endpoint.childDialog.expectsJSON)
        #expect(CourseSelectionAPI.Endpoint.childDialog.method == "POST")
        #expect(CourseSelectionAPI.Endpoint.childDialog.urlString == SchoolDirectAPI.courseSelectionChildDialogURL)
        #expect(CourseSelectionAPI.Endpoint.childClasses.expectsJSON)
        #expect(CourseSelectionAPI.Endpoint.catalog.expectsJSON)
    }
}
