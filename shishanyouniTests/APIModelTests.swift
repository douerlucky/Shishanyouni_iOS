//
//  APIModelTests.swift
//  shishanyouniTests
//
//  用脱敏 JSON 检查接口模型迁移后的编码与解码兼容性，不发送网络请求。
//

import Foundation
import Testing
@testable import shishanyouni

struct APIModelTests
{
    @Test("馆藏请求保留后端字段名和搜索类型值")
    func libraryRequestsEncodeBackendFields() throws
    {
        for (type, expectedValue) in [(SearchType.anyWord, "wrd"), (.title, "wti"), (.author, "wau")]
        {
            let request = BookListRequest(kw: "计算机", searchType: type, page: 2)
            let data = try JSONEncoder().encode(request)
            let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            #expect(json["kw"] as? String == "计算机")
            #expect(json["searchType"] as? String == expectedValue)
            #expect(json["page"] as? Int == 2)
        }

        let detail = try JSONEncoder().encode(BookDetailRequest(rd: "KWDG44E7J9", no: "556627"))
        let json = try #require(JSONSerialization.jsonObject(with: detail) as? [String: String])
        #expect(json == ["rd": "KWDG44E7J9", "no": "556627"])
    }

    @Test("馆藏响应保留书籍标识、空字段和副本状态")
    func libraryResponsesDecodeBooksAndCopies() throws
    {
        let list = try decode(BookListResponse.self, json: """
        {"msg":"成功","code":2,"data":{"bookList":[
          {"name":"计算机科学导论","author":"战德臣","publish":" / ","rd":"KWDG44E7J9","no":"556627"}
        ],"page":1,"totalCnt":1}}
        """)
        #expect(list.data?.bookList.first?.id == "KWDG44E7J9-556627")

        let response = try decode(BookDetailResponse.self, json: """
        {"msg":"成功","code":2,"data":{
          "title":"计算机科学导论","author":"战德臣","publisher":"","isbn":"978-7-04-064589-7",
          "classification":"TP3","bookInfo":null,"authorInfo":null,"siteList":[
            {"room":"中文样本库1","location":"39排A面6节","status":"在架上","number":"98314723"},
            {"room":"自科图书借阅室","location":"21排B面5节","status":"不在架上","number":"98314724"}
          ]}}
        """)
        let detail = try #require(response.data)
        #expect(detail.publisher.isEmpty)
        #expect(detail.siteList.map(\.isAvailable) == [true, false])
    }

    @Test("成绩两种数据源仍可解码缺少可选字段的响应")
    func gradeResponsesKeepOptionalFields() throws
    {
        let gradeJSON = #"{"jxb_id":"class-1","kcmc":"线性代数","xf":"3","cj":"90","jd":"4.0"}"#
        let direct = try decode(TeachingSystemGradeResponse.self, json: "{\"items\":[\(gradeJSON)]}")
        let lion = try decode(LionGradeResponse.self, json: "{\"code\":2,\"data\":[\(gradeJSON)]}")
        #expect(direct.items.first?.kcmc == "线性代数")
        #expect(lion.data?.first?.cj == "90")
        #expect(lion.data?.first?.xh_id == nil)
        #expect(lion.data?.first?.effectiveQuerySource == .shishanyouni)
    }

    @Test("考试响应区分教务记录和狮山有你原始数据")
    func examResponsesDecodeBothSources() throws
    {
        let direct = try decode(ExamResponse.self, json: """
        {"items":[{"row_id":8,"kcmc":"线性代数","ksmc":"期末考试","kssj":"2027-01-10(08:00-10:00)","cdmc":"三教A101"}]}
        """)
        #expect(direct.items.first?.id == "8")
        #expect(direct.items.first?.querySource == .cas)

        let lion = try decode(LionExamResponse.self, json: """
        {"code":2,"data":[{"kcmc":"线性代数","ksmc":"期末考试","kssj":"2027-01-10(08:00-10:00)","cdmc":null}]}
        """)
        #expect(lion.isSuccess)
        #expect(lion.data?.first?.cdmc == nil)
    }

    @Test("绑定响应继续兼容数字和字符串状态码")
    func accountResponsesKeepFlexibleCodeParsing()
    {
        for code in [22, "22"] as [Any]
        {
            let response = ShishanyouniBindResponse(json: [
                "msg": "需要短信验证", "code": code,
                "data": ["phone": "133****0000", "sessionId": "test-session"]
            ])
            #expect(response.code == 22)
            #expect(response.data?.sessionId == "test-session")
        }
        let code = ShishanyouniCodeResponse(json: ["code": "2", "msg": "成功", "data": "已发送"])
        #expect(code.code == 2)
        #expect(code.data == "已发送")
        #expect(ShishanyouniBindResponse(json: ["code": NSNull()]).code == nil)
    }

    @Test("CAS 安全验证模型保留动态校验服务器和可选字段")
    func casMFAResponsesDecode() throws
    {
        let detect = try decode(CASMFADetectResponse.self, json: #"{"code":0,"data":{"need":true,"state":"test-state","mfaTypeSecurePhone":true}}"#)
        let initial = try decode(CASMFAInitResponse.self, json: #"{"code":0,"data":{"gid":"test-gid","securePhone":null,"attestServerUrl":"https://example.com/mfa"}}"#)
        let verified = try decode(CASMFACommonResponse.self, json: #"{"code":0,"data":{"result":"success","status":1},"message":null}"#)
        #expect(detect.data?.need == true)
        #expect(initial.data?.attestServerUrl == "https://example.com/mfa")
        #expect(initial.data?.securePhone == nil)
        #expect(verified.data?.status == 1)
    }

    @Test("课表请求继续省略空 token 并发送 type=0")
    func timetableRequestPreservesEncoding() throws
    {
        for token in [nil, "test-token"] as [String?]
        {
            let request = TimetableRequest(username: "test-user", password: "encrypted", token: token, year: "2026", term: "1")
            let data = try JSONEncoder().encode(request)
            let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            #expect(json["token"] as? String == token)
            #expect(json["type"] as? Int == 0)
            #expect(json["year"] as? String == "2026")
        }
    }

    @Test("课表新旧字段都能转换成本地 Course")
    func timetableResponsesKeepLegacyAliases() throws
    {
        for (listKey, startKey, stepKey) in [("timetableModels", "start", "step"), ("timeTable", "period", "length")]
        {
            let response = try decode(TimetableResponse.self, json: """
            {"code":2,"data":{"\(listKey)":[{
              "name":"线性代数","day":1,"\(startKey)":1,"\(stepKey)":2,
              "weekList":[1,2],"room":"三教A101","teacher":"老师","khfsmc":"考试"
            }]}}
            """)
            let model = try #require(response.data?.timetableModels.first)
            let course = Course(from: model)
            #expect(response.isSuccess)
            #expect(course.start == 1)
            #expect(course.step == 2)
            #expect(course.assessmentMethod == "考试")
            #expect(course.shortName == nil)
        }
    }

    @Test("课程列表和详情响应保留各自的数据格式")
    func courseResponsesDecode() throws
    {
        let direct = try decode(AllCourseResponse.self, json: """
        {"items":[{"row_id":"1","kch_id":"course-1","kch":"001","kcmc":"线性代数","xnm":"2026","xqm":"3"}]}
        """)
        let classes = try decode(CourseClassResponse.self, json: #"{"kbList":[{"jxb_id":"class-1","jxbmc":"线性代数-1"}]}"#)
        let item = #"{"id":1,"cname":"线性代数","classCode":"class-1","schoolYear":"2026","schoolTerm":"1"}"#
        let lion = try decode(LionRubKeywordResponse.self, json: "{\"code\":2,\"data\":[\(item)]}")
        let detail = try decode(LionRubDetailResponse.self, json: """
        {"code":200,"data":{"rubList":[\(item)],"tableRes":[{"day":1,"period":1,"length":2,"week":"1-16周","weeks":[1,2]}]}}
        """)
        #expect(direct.items.first?.kcmc == "线性代数")
        #expect(classes.kbList.first?.jxb_id == "class-1")
        #expect(lion.isSuccess)
        #expect(detail.data?.tableRes?.first?.length == 2)
    }

    @Test("南湖跑原始响应仍可供业务模型转换")
    func gymCloudResponseDecodes() throws
    {
        let response = try decode(LionSouthlakeResponse.self, json: #"{"code":2,"data":{"items":[{"term":"2026-2027-1","num":"10"}]}}"#)
        #expect(response.isSuccess)
        #expect(response.data?.items?.first?.num == "10")
    }

    @Test("电费响应保留电表数据和最新抄表时间")
    func electricityBalanceResponseDecodes() throws
    {
        let response = try decode(ElectricityResponse.self, json: """
        {"code":200,"msg":"成功","data":{"records":[{
          "roomId":"room-1","roomName":"101","accountAddress":"1栋101","balance":"25.50",
          "baseMeterList":[{"meterCode":"meter-1","lastReading":12.5,"lastReadingTime":"2026-10-13 08:00"}]
        }]}}
        """)
        #expect(response.data?.records.first?.balance == "25.50")
        #expect(response.data?.records.first?.lastUpdate == "2026-10-13 08:00")
    }

    @Test("电费选择器继续兼容数组和分页对象")
    func electricityPickerResponseKeepsBothShapes() throws
    {
        let items = #"[{"label":"1栋","value":"building-1"}]"#
        for data in [items, "{\"records\":\(items)}"]
        {
            let response = try decode(BuildingLevelRoomResponse.self, json: "{\"code\":200,\"msg\":\"成功\",\"data\":\(data)}")
            let rows: [PickerItem]
            switch try #require(response.data)
            {
            case let .array(items): rows = items
            case let .object(page): rows = page.records
            }
            #expect(rows.first?.label == "1栋")
            #expect(rows.first?.id == "building-1")
        }
    }

    @Test("空教室响应仍使用五个时间段状态")
    func classroomResponseDecodes() throws
    {
        let response = try decode(ClassroomResponse.self, json: #"{"code":2,"data":[[0,1,0,1,0]],"success":true}"#)
        #expect(response.data == [[0, 1, 0, 1, 0]])
    }

    @Test("攻略列表和详情可以直接供界面使用")
    func guideResponsesDecode() throws
    {
        let item = #"{"id":1,"name":"校园生活指南","context":"<p>指南内容</p>","author":null}"#
        let list = try decode(GuideResponse.self, json: "{\"msg\":\"成功\",\"code\":2,\"data\":[\(item)]}")
        let detail = try decode(GuideDetailResponse.self, json: "{\"msg\":\"成功\",\"code\":2,\"data\":\(item)}")
        #expect(list.data?.first?.name == "校园生活指南")
        #expect(detail.data?.context == "<p>指南内容</p>")
    }

    @Test("社团列表和详情保留不同的联系方式字段类型")
    func clubResponsesKeepDifferentContactTypes() throws
    {
        let list = try decode(ClubListResponse.self, json: """
        {"msg":"成功","code":2,"success":true,"data":[[
          {"id":1,"name":"读书社","avatar":"","contact":"test@example.com"}
        ]]}
        """)
        let detail = try decode(ClubDetailResponse.self, json: """
        {"msg":"成功","code":2,"success":true,"data":{
          "id":1,"name":"读书社","avatar":"","contact":["test@example.com"]
        }}
        """)
        #expect(list.data.first?.first?.contact == "test@example.com")
        #expect(detail.data.contact == ["test@example.com"])
    }

    private func decode<T: Decodable>(_ type: T.Type, json: String) throws -> T
    {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }
}
