import Foundation
import Testing
@testable import shishanyouni

/// 只检查地址常量，不登录学校系统，也不发送真实查询、选课或退课请求。
struct APIEndpointTests
{
    @Test("集中管理后，现有固定 URL 保持原样")
    func preservesExistingURLs()
    {
        // 这些字面量是迁移前的协议快照；修改接口时应先核对服务端再更新断言。
        let endpoints: [(actual: String, expected: String)] = [
            (SchoolDirectAPI.casOrigin, "https://cas-paas.hzau.edu.cn"),
            (SchoolDirectAPI.casRootURL, "https://cas-paas.hzau.edu.cn/"),
            (SchoolDirectAPI.casPortalLoginURL, "https://cas-paas.hzau.edu.cn/cas/login?service=https://portal-paas.hzau.edu.cn/"),
            (SchoolDirectAPI.casElectricityLoginURL, "https://cas-paas.hzau.edu.cn/cas/login?service=https%3A%2F%2Fsdgl.hzau.edu.cn%2Fapi%2Fsso%2Fmobile%2Fcallback%3FtargetUrl%3Dhttps%3A%2F%2Fsdgl.hzau.edu.cn%2Fapi%2Fsso%2Fmobile%2Fcallback"),
            (SchoolDirectAPI.casGymLoginURL, "https://cas-paas.hzau.edu.cn/cas/login?service=https://tygl.hzau.edu.cn/"),
            (SchoolDirectAPI.casITCLoginURL, "https://cas-paas.hzau.edu.cn/cas/login?service=https%3A%2F%2Fitc.hzau.edu.cn%2F"),
            (SchoolDirectAPI.mfaDetectURL, "https://cas-paas.hzau.edu.cn/cas/mfa/detect"),
            (SchoolDirectAPI.mfaInitSecurePhoneURL, "https://cas-paas.hzau.edu.cn/cas/mfa/initByType/securephone"),
            (SchoolDirectAPI.academicOrigin, "http://byjxyt.hzau.edu.cn"),
            (SchoolDirectAPI.academicTimetableReferer, "http://byjxyt.hzau.edu.cn/kbcx/xskbcx_cxXskbcxIndex.html?gnmkdm=N2151&layout=default"),
            (SchoolDirectAPI.timetableURL, "http://byjxyt.hzau.edu.cn/kbcx/xskbcxMobile_cxXsKb.html"),
            (SchoolDirectAPI.timetableReferer, "http://byjxyt.hzau.edu.cn/kbcx/xskbcxMobile_cxTimeTableIndex.html?gnmkdm=N2190&layout=default"),
            (SchoolDirectAPI.courseSearchURL, "http://byjxyt.hzau.edu.cn/kbdy/kckbdy_cxKckbdyList.html?gnmkdm=N214520"),
            (SchoolDirectAPI.courseDetailURL, "http://byjxyt.hzau.edu.cn/kbdy/kckbdy_cxKcKb.html?gnmkdm=N214520"),
            (SchoolDirectAPI.examURL, "http://byjxyt.hzau.edu.cn/kwgl/kscx_cxXsksxxIndex.html?doType=query&gnmkdm=N358105"),
            (SchoolDirectAPI.schoolCalendarURL, "http://byjxyt.hzau.edu.cn/pkgl/xlglMobile_cxXlIndexForxs.html"),
            (SchoolDirectAPI.teachingSystemOrigin, "http://jwgl.hzau.edu.cn"),
            (SchoolDirectAPI.teachingSystemSSOURL, "http://jwgl.hzau.edu.cn/sso/hnyyxyiotlogin"),
            (SchoolDirectAPI.gradeListURL, "http://jwgl.hzau.edu.cn/cjcx/cjcx_cxXsgrcj.html?doType=query&gnmkdm=N305005"),
            (SchoolDirectAPI.gradeDetailURL, "http://jwgl.hzau.edu.cn/cjcx/cjcx_cxCjxqGjh.html"),
            (SchoolDirectAPI.gradeReferer, "http://jwgl.hzau.edu.cn/cjcx/cjcx_cxDgXscj.html?gnmkdm=N305005&layout=default"),
            (SchoolDirectAPI.courseSelectionIndexURL, "http://byjxyt.hzau.edu.cn/xsxk/zzxkyzb_cxZzxkYzbIndex.html?gnmkdm=N253512&layout=default"),
            (SchoolDirectAPI.courseSelectionDisplayURL, "http://byjxyt.hzau.edu.cn/xsxk/zzxkyzb_cxZzxkYzbDisplay.html"),
            (SchoolDirectAPI.courseSelectionCatalogURL, "http://byjxyt.hzau.edu.cn/xsxk/zzxkyzb_cxZzxkYzbPartDisplay.html?gnmkdm=N253512"),
            (SchoolDirectAPI.courseSelectionParentClassURL, "http://byjxyt.hzau.edu.cn/xsxk/zzxkyzb_cxJxbWithKchZzxkYzb.html?gnmkdm=N253512"),
            (SchoolDirectAPI.courseSelectionChildDialogURL, "http://byjxyt.hzau.edu.cn/xsxk/zzxkyzb_xkZyZzxkYzbZjxb.html?gnmkdm=N253512"),
            (SchoolDirectAPI.courseSelectionChildDisplayURL, "http://byjxyt.hzau.edu.cn/xsxk/zzxkyzb_xkZyDisplayZzxkYzbZjxb.html?gnmkdm=N253512"),
            (SchoolDirectAPI.courseSelectionSubmitURL, "http://byjxyt.hzau.edu.cn/xsxk/zzxkyzb_xkBcZyZzxkYzb.html?gnmkdm=N253512"),
            (SchoolDirectAPI.courseSelectionDropCheckURL, "http://byjxyt.hzau.edu.cn/xsxk/zzxkyzb_xkJcInXksjZzxkYzb.html?gnmkdm=N253512"),
            (SchoolDirectAPI.courseSelectionDropURL, "http://byjxyt.hzau.edu.cn/xsxk/zzxkyzb_tuikBcZzxkYzb.html?gnmkdm=N253512"),
            (SchoolDirectAPI.courseSelectionPreferenceSyncURL, "http://byjxyt.hzau.edu.cn/xsxk/zzxkyzb_xkBcZypxZzxkYzb.html?gnmkdm=N253512"),
            (SchoolDirectAPI.selectedClassSchedulesURL, "http://byjxyt.hzau.edu.cn/xsxk/zzxkyzb_cxZkcZzxkYzb.html?gnmkdm=N253512"),
            (SchoolDirectAPI.selectedCoursesURL, "http://byjxyt.hzau.edu.cn/xsxk/zzxkyzb_cxZzxkYzbChoosedDisplay.html?gnmkdm=N253512"),
            (SchoolDirectAPI.electricityOrigin, "https://sdgl.hzau.edu.cn"),
            (SchoolDirectAPI.electricityBaseURL, "https://sdgl.hzau.edu.cn/api/base"),
            (SchoolDirectAPI.electricitySearchMeterReferer, "https://sdgl.hzau.edu.cn/mobile/pages/module/search-meter"),
            (SchoolDirectAPI.electricityBindingSearchReferer, "https://sdgl.hzau.edu.cn/mobile/pages/module/search?url=%2Fpages%2FbindingAccount%2Faccountbind"),
            (SchoolDirectAPI.electricityBindingPageURL, "https://sdgl.hzau.edu.cn/mobile/pages/bindingAccount/accountbind"),
            (SchoolDirectAPI.gymRootURL, "https://tygl.hzau.edu.cn/"),
            (SchoolDirectAPI.gymRunScoreURL, "https://tygl.hzau.edu.cn/main.php?module=stu&title=stu_sun_score"),
            (SchoolDirectAPI.gymPhysicalScoreURL, "https://tygl.hzau.edu.cn/main.php?module=stu&title=stu_ht_score"),
            (SchoolDirectAPI.gymReferer, "https://tygl.hzau.edu.cn/main.php"),
            (SchoolDirectAPI.itcOrigin, "https://itc.hzau.edu.cn"),
            (SchoolDirectAPI.itcCourseListURL, "https://itc.hzau.edu.cn/courselist.jsp?courseID=0"),
            (SchoolDirectAPI.librarySeatURL, "https://libseat.hzau.edu.cn/self"),
            (SchoolDirectAPI.campusMapURL, "http://gis.hzau.edu.cn/index.shtml"),
            (SchoolDirectAPI.campusBusURL, "https://car.hzau.edu.cn/passenger/pages/map"),
            (SchoolDirectAPI.schoolCalendarArticleURL, "https://open.work.weixin.qq.com/wwopen/mpnews?mixuin=lu0DCgAABwCtk1udAAAUAA&mfid=WW0330-Z_3nCwAABwA3LVBi1SETCAdPydka6&idx=0&sn=31fb6968b113196aeff1db5776c0fcc2&version=5.0.9.6029&platform=win"),
            (ShishanyouniAPI.origin, "https://lion.hzau.edu.cn"),
            (ShishanyouniAPI.bindURL, "https://lion.hzau.edu.cn/app/ios/bind"),
            (ShishanyouniAPI.sendCodeURL, "https://lion.hzau.edu.cn/app/ios/sendCode"),
            (ShishanyouniAPI.submitCodeURL, "https://lion.hzau.edu.cn/app/ios/submitCode"),
            (ShishanyouniAPI.timetableURL, "https://lion.hzau.edu.cn/app/ios/timetable"),
            (ShishanyouniAPI.gradeURL, "https://lion.hzau.edu.cn/app/ios/score"),
            (ShishanyouniAPI.examURL, "https://lion.hzau.edu.cn/app/ios/exam"),
            (ShishanyouniAPI.classroomURL, "https://lion.hzau.edu.cn/app/ios/freeroom/getToday"),
            (ShishanyouniAPI.courseSearchURL, "https://lion.hzau.edu.cn/app/ios/rub/keyword"),
            (ShishanyouniAPI.courseDetailURL, "https://lion.hzau.edu.cn/app/ios/rub/getByClassCode"),
            (ShishanyouniAPI.southlakeURL, "https://lion.hzau.edu.cn/app/ios/southlake"),
            (ShishanyouniAPI.bookListURL, "https://lion.hzau.edu.cn/app/ios/library/bookList"),
            (ShishanyouniAPI.bookDetailURL, "https://lion.hzau.edu.cn/app/ios/library/bookDetail"),
            (ShishanyouniAPI.guideListURL, "https://lion.hzau.edu.cn/app/ios/guide/getinfo"),
            (ShishanyouniAPI.guideDetailURL, "https://lion.hzau.edu.cn/app/ios/guide/findbyid"),
            (ShishanyouniAPI.clubListURL, "https://lion.hzau.edu.cn/app/ios/club/getall"),
            (ShishanyouniAPI.clubDetailURL, "https://lion.hzau.edu.cn/app/ios/club/getbyid")
        ]

        for endpoint in endpoints
        {
            #expect(endpoint.actual == endpoint.expected)
            #expect(URL(string: endpoint.actual) != nil)
        }
    }

    @Test("固定路径与动态参数的拼接保持兼容")
    func preservesDynamicURLComposition()
    {
        #expect(
            "\(SchoolDirectAPI.electricityFloorListURL)?buildingId=42"
                == "https://sdgl.hzau.edu.cn/api/base/rooms/getAllFoolNumByBuildId?buildingId=42"
        )
        #expect(
            "\(SchoolDirectAPI.electricityRoomListURL)?floorNum=3&buildingId=42"
                == "https://sdgl.hzau.edu.cn/api/base/rooms/getRoomListByBuildIdAndFloor?floorNum=3&buildingId=42"
        )
        #expect(
            SchoolDirectAPI.electricityBuildingListURL
                == "https://sdgl.hzau.edu.cn/api/base/baseBuildings/getBuildList?size=999&current=1"
        )
        #expect(
            SchoolDirectAPI.electricityRoomQueryURL
                == "https://sdgl.hzau.edu.cn/api/base/rooms/queryRoomList"
        )
        #expect(
            "\(SchoolDirectAPI.itcOrigin)\(SchoolDirectAPI.itcCourseListPath)?courseID=100"
                == "https://itc.hzau.edu.cn/courselist.jsp?courseID=100"
        )
        #expect(
            "\(SchoolDirectAPI.itcOrigin)\(SchoolDirectAPI.itcAssignmentPath)?courseID=100&assignID=200"
                == "https://itc.hzau.edu.cn/assignment/index.jsp?courseID=100&assignID=200"
        )
        #expect(
            "\(ShishanyouniAPI.guideDetailURL)?id=42"
                == "https://lion.hzau.edu.cn/app/ios/guide/findbyid?id=42"
        )
        #expect(
            "\(ShishanyouniAPI.clubDetailURL)?id=42"
                == "https://lion.hzau.edu.cn/app/ios/club/getbyid?id=42"
        )
    }

    @Test("MFA 验证仍使用认证响应提供的服务器")
    func preservesServerProvidedMFABaseURL()
    {
        let serverURL = "https://mfa.example.test"
        #expect(serverURL + SchoolDirectAPI.securePhoneSendPath == "https://mfa.example.test/api/guard/securephone/send")
        #expect(serverURL + SchoolDirectAPI.securePhoneVerifyPath == "https://mfa.example.test/api/guard/securephone/valid")
    }
}
