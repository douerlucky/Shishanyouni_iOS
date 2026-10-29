import Foundation

// 关注教室的数据结构。


// MARK: - 关注教室模型

/// 关注的单个教室（持久化）
struct FavoriteClassroom: Codable, Identifiable, Equatable
{
    let id: UUID
    /// API 查询参数，如 "三教A3"、"一教2"
    let siteName: String
    /// 在该楼层 data 数组中的 0-based 下标，如第1间教室 = 0
    let arrayIndex: Int
    /// UI 显示名称，如 "三教A301"、"一教201"
    let displayName: String
}
