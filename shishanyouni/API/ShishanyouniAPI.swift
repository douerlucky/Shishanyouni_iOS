// 狮山有你后端的固定接口地址。
// 请求参数、编码、解析和错误处理继续由原来的功能服务负责。

/// 所有 lion 接口共用同一个入口，域名变化时只需修改 origin。
enum ShishanyouniAPI
{
    static let origin = "https://lion.hzau.edu.cn"
    private static let iosBaseURL = origin + "/app/ios"

    // MARK: - 账号绑定与短信验证

    static let bindURL = iosBaseURL + "/bind"
    static let sendCodeURL = iosBaseURL + "/sendCode"
    static let submitCodeURL = iosBaseURL + "/submitCode"

    // MARK: - 课表、成绩、考试与空教室

    static let timetableURL = iosBaseURL + "/timetable"
    static let gradeURL = iosBaseURL + "/score"
    static let examURL = iosBaseURL + "/exam"
    static let classroomURL = iosBaseURL + "/freeroom/getToday"

    // MARK: - 课程查询与环湖跑

    static let courseSearchURL = iosBaseURL + "/rub/keyword"
    static let courseDetailURL = iosBaseURL + "/rub/getByClassCode"
    static let southlakeURL = iosBaseURL + "/southlake"

    // MARK: - 图书馆馆藏

    static let bookListURL = iosBaseURL + "/library/bookList"
    static let bookDetailURL = iosBaseURL + "/library/bookDetail"

    // MARK: - 攻略与社团

    static let guideListURL = iosBaseURL + "/guide/getinfo"
    static let guideDetailURL = iosBaseURL + "/guide/findbyid"
    static let clubListURL = iosBaseURL + "/club/getall"
    static let clubDetailURL = iosBaseURL + "/club/getbyid"
}
