import Foundation

//
//  ExamAPIModels.swift
//  shishanyouni
//
//  教务系统与狮山有你考试接口的响应。
//  这里只定义接口的数据格式；请求执行、错误处理和界面状态留在业务模块。
//


// 教务响应直接解码为 Exam；狮山有你响应先解码 LionExamItem，再由业务模块转换。
struct ExamResponse: Decodable
{
    let items: [Exam]
}

struct LionExamResponse: Decodable {
    let msg: String?
    let code: Int
    let data: [LionExamItem]?
    let success: Bool?

    var isSuccess: Bool {
        success == true || code == 2 || code == 200
    }
}

struct LionExamItem: Decodable {
    let xm: String?
    let xh: String?
    let kcmc: String
    let ksmc: String
    let kssj: String
    let cdmc: String?
    let bj: String?
}
