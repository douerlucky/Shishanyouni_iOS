import Foundation

// MARK: - 计算器专用数据模型

struct CalcPhysicalDetail: Identifiable
{
    let id = UUID()
    var project: String
    var result: String = "" // 用户输入内容
    var score: String = "-" // 计算后的单项分
    var grade: String = "待输入" // 等级：不及格/及格/良好/优秀
    var isBMI: Bool = false
}
