// 学校直连接口、固定请求头地址及公开网页入口。
// 本文件只维护地址，不保存账号、Cookie、Token，也不负责发送请求。

/// 保留现有协议、固定查询参数和 CAS service 编码，避免地址整理改变认证行为。
enum SchoolDirectAPI
{
    // MARK: - CAS 登录与多因子认证

    static let casOrigin = "https://cas-paas.hzau.edu.cn"
    static let casRootURL = casOrigin + "/"
    static let casPortalLoginURL = casOrigin + "/cas/login?service=https://portal-paas.hzau.edu.cn/"
    static let casElectricityLoginURL = casOrigin + "/cas/login?service=https%3A%2F%2Fsdgl.hzau.edu.cn%2Fapi%2Fsso%2Fmobile%2Fcallback%3FtargetUrl%3Dhttps%3A%2F%2Fsdgl.hzau.edu.cn%2Fapi%2Fsso%2Fmobile%2Fcallback"
    static let casGymLoginURL = casOrigin + "/cas/login?service=https://tygl.hzau.edu.cn/"
    static let casITCLoginURL = casOrigin + "/cas/login?service=https%3A%2F%2Fitc.hzau.edu.cn%2F"
    static let mfaDetectURL = casOrigin + "/cas/mfa/detect"
    static let mfaInitSecurePhoneURL = casOrigin + "/cas/mfa/initByType/securephone"

    /// MFA 验证服务器由认证响应提供；这里只统一固定路径，不硬编码其域名。
    static let securePhoneSendPath = "/api/guard/securephone/send"
    static let securePhoneVerifyPath = "/api/guard/securephone/valid"
    static let casLoginResponseMarker = "cas-paas.hzau.edu.cn/cas/login"
    static let portalHost = "portal-paas.hzau.edu.cn"

    // MARK: - 教务一体化：课表、课程、考试与校历

    static let academicOrigin = "http://byjxyt.hzau.edu.cn"
    static let academicTimetableReferer = academicOrigin + "/kbcx/xskbcx_cxXskbcxIndex.html?gnmkdm=N2151&layout=default"
    static let timetableURL = academicOrigin + "/kbcx/xskbcxMobile_cxXsKb.html"
    static let timetableReferer = academicOrigin + "/kbcx/xskbcxMobile_cxTimeTableIndex.html?gnmkdm=N2190&layout=default"
    static let courseSearchURL = academicOrigin + "/kbdy/kckbdy_cxKckbdyList.html?gnmkdm=N214520"
    static let courseDetailURL = academicOrigin + "/kbdy/kckbdy_cxKcKb.html?gnmkdm=N214520"
    static let examURL = academicOrigin + "/kwgl/kscx_cxXsksxxIndex.html?doType=query&gnmkdm=N358105"
    static let schoolCalendarURL = academicOrigin + "/pkgl/xlglMobile_cxXlIndexForxs.html"

    // MARK: - 教务系统：成绩

    static let teachingSystemOrigin = "http://jwgl.hzau.edu.cn"
    static let teachingSystemSSOURL = teachingSystemOrigin + "/sso/hnyyxyiotlogin"
    static let gradeListURL = teachingSystemOrigin + "/cjcx/cjcx_cxXsgrcj.html?doType=query&gnmkdm=N305005"
    static let gradeDetailURL = teachingSystemOrigin + "/cjcx/cjcx_cxCjxqGjh.html"
    static let gradeReferer = teachingSystemOrigin + "/cjcx/cjcx_cxDgXscj.html?gnmkdm=N305005&layout=default"

    // MARK: - 选课与退课

    static let courseSelectionIndexURL = academicOrigin + "/xsxk/zzxkyzb_cxZzxkYzbIndex.html?gnmkdm=N253512&layout=default"
    static let courseSelectionDisplayURL = academicOrigin + "/xsxk/zzxkyzb_cxZzxkYzbDisplay.html"
    static let courseSelectionCatalogURL = academicOrigin + "/xsxk/zzxkyzb_cxZzxkYzbPartDisplay.html?gnmkdm=N253512"
    static let courseSelectionParentClassURL = academicOrigin + "/xsxk/zzxkyzb_cxJxbWithKchZzxkYzb.html?gnmkdm=N253512"
    static let courseSelectionChildDialogURL = academicOrigin + "/xsxk/zzxkyzb_xkZyZzxkYzbZjxb.html?gnmkdm=N253512"
    static let courseSelectionChildDisplayURL = academicOrigin + "/xsxk/zzxkyzb_xkZyDisplayZzxkYzbZjxb.html?gnmkdm=N253512"
    static let courseSelectionSubmitURL = academicOrigin + "/xsxk/zzxkyzb_xkBcZyZzxkYzb.html?gnmkdm=N253512"
    static let courseSelectionDropCheckURL = academicOrigin + "/xsxk/zzxkyzb_xkJcInXksjZzxkYzb.html?gnmkdm=N253512"
    static let courseSelectionDropURL = academicOrigin + "/xsxk/zzxkyzb_tuikBcZzxkYzb.html?gnmkdm=N253512"
    static let courseSelectionPreferenceSyncURL = academicOrigin + "/xsxk/zzxkyzb_xkBcZypxZzxkYzb.html?gnmkdm=N253512"
    /// 教学班参数来自当前会话，不在这里保存或复用其它账号的 jxb_ids。
    static let selectedClassSchedulesURL = academicOrigin + "/xsxk/zzxkyzb_cxZkcZzxkYzb.html?gnmkdm=N253512"
    static let selectedCoursesURL = academicOrigin + "/xsxk/zzxkyzb_cxZzxkYzbChoosedDisplay.html?gnmkdm=N253512"

    // MARK: - 电费系统

    static let electricityOrigin = "https://sdgl.hzau.edu.cn"
    static let electricityBaseURL = electricityOrigin + "/api/base"
    static let electricitySearchMeterReferer = electricityOrigin + "/mobile/pages/module/search-meter"
    static let electricityBindingSearchReferer = electricityOrigin + "/mobile/pages/module/search?url=%2Fpages%2FbindingAccount%2Faccountbind"
    static let electricityBindingPageURL = electricityOrigin + "/mobile/pages/bindingAccount/accountbind"

    static let electricityBuildingListURL = electricityBaseURL + "/baseBuildings/getBuildList?size=999&current=1"
    static let electricityFloorListURL = electricityBaseURL + "/rooms/getAllFoolNumByBuildId"
    static let electricityRoomListURL = electricityBaseURL + "/rooms/getRoomListByBuildIdAndFloor"
    static let electricityRoomQueryURL = electricityBaseURL + "/rooms/queryRoomList"

    // MARK: - 体测与环湖跑

    static let gymOrigin = "https://tygl.hzau.edu.cn"
    static let gymRootURL = gymOrigin + "/"
    static let gymRunScoreURL = gymOrigin + "/main.php?module=stu&title=stu_sun_score"
    static let gymPhysicalScoreURL = gymOrigin + "/main.php?module=stu&title=stu_ht_score"
    static let gymReferer = gymOrigin + "/main.php"

    // MARK: - ITC 作业平台

    static let itcOrigin = "https://itc.hzau.edu.cn"
    static let itcCourseListURL = itcOrigin + "/courselist.jsp?courseID=0"

    /// 相对路径供现有 ITC 请求构造器使用；课程、作业 ID 仍由调用方传入。
    static let itcCourseListPath = "/courselist.jsp"
    static let itcAssignmentPath = "/assignment/index.jsp"

    // MARK: - 学校公开网页入口

    static let librarySeatURL = "https://libseat.hzau.edu.cn/self"
    static let campusMapURL = "http://gis.hzau.edu.cn/index.shtml"
    static let campusBusURL = "https://car.hzau.edu.cn/passenger/pages/map"
    static let schoolCalendarArticleURL = "https://open.work.weixin.qq.com/wwopen/mpnews?mixuin=lu0DCgAABwCtk1udAAAUAA&mfid=WW0330-Z_3nCwAABwA3LVBi1SETCAdPydka6&idx=0&sn=31fb6968b113196aeff1db5776c0fcc2&version=5.0.9.6029&platform=win"
}
