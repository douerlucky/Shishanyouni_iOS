// 狮山有你后端的固定接口地址。
// 登录与个人业务使用 v3；公开接口保留原路径。

/// 所有 lion 接口共用同一个入口，域名变化时只需修改 origin。
enum ShishanyouniAPI
{
    static let origin = "https://lion.hzau.edu.cn"
    private static let iosBaseURL = origin + "/app/ios"
    static let v3BaseURL = iosBaseURL + "/v3"

    // MARK: - 账号绑定与短信验证

    static let bindURL = v3BaseURL + "/bind"
    static let sendCodeURL = v3BaseURL + "/sendCode"
    static let submitCodeURL = v3BaseURL + "/submitCode"
    static let revokeURL = v3BaseURL + "/revoke"

    // MARK: - 课表、成绩、考试与空教室

    static let timetableURL = v3BaseURL + "/timetable"
    static let gradeURL = v3BaseURL + "/score"
    static let examURL = v3BaseURL + "/exam"
    static let classroomURL = iosBaseURL + "/freeroom/getToday"

    // MARK: - 课程查询与环湖跑

    static let courseSearchURL = iosBaseURL + "/rub/keyword"
    static let courseDetailURL = iosBaseURL + "/rub/getByClassCode"
    static let southlakeURL = v3BaseURL + "/southlake"

    // MARK: - 图书馆馆藏

    static let bookListURL = iosBaseURL + "/library/bookList"
    static let bookDetailURL = iosBaseURL + "/library/bookDetail"

    // MARK: - 攻略与社团

    static let guideListURL = iosBaseURL + "/guide/getinfo"
    static let guideDetailURL = iosBaseURL + "/guide/findbyid"
    static let clubListURL = iosBaseURL + "/club/getall"
    static let clubDetailURL = iosBaseURL + "/club/getbyid"
}
