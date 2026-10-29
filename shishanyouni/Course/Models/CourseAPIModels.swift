import Foundation

//
//  CourseAPIModels.swift
//  shishanyouni
//
//  全校课程搜索与教学班详情接口的响应。
//  这里只定义接口的数据格式；请求执行、错误处理和界面状态留在业务模块。
//


// CourseInfo / CourseClassInfo 保留在课程模块，统一两种数据源供页面使用。
// MARK: - CAS 响应模型

struct AllCourseResponse: Decodable
{
    let items: [CourseInfo]
}

struct CourseClassResponse: Decodable
{
    let kbList: [CourseClassInfo]
}

// MARK: - 狮山有你响应模型

struct LionRubKeywordResponse: Decodable
{
    let msg: String?
    let code: Int
    let data: [LionRubKeywordItem]?
    let success: Bool?

    var isSuccess: Bool
    {
        success == true || code == 2 || code == 200
    }
}

struct LionRubKeywordItem: Decodable
{
    let id: Int
    let weekday: String?
    let classTime: String?
    let week: String?
    let cno: String?
    let cname: String
    let tname: String?
    let siteName: String?
    let courseNature: String?
    let className: String?
    let classCode: String
    let courseId: String?
    let schoolYear: String
    let schoolTerm: String
    let type: Int?
    let teacherNum: Int?
}

struct LionRubDetailResponse: Decodable
{
    let msg: String?
    let code: Int
    let data: LionRubDetailData?
    let success: Bool?

    var isSuccess: Bool
    {
        success == true || code == 2 || code == 200
    }
}

struct LionRubDetailData: Decodable
{
    let rubList: [LionRubKeywordItem]?
    let tableRes: [LionRubTableItem]?
}

struct LionRubTableItem: Decodable
{
    let day: Int
    let period: Int
    let length: Int
    let name: String?
    let room: String?
    let teacher: String?
    let week: String?
    let weeks: [Int]?
}
