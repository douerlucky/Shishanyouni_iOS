// 学业查询缓存的公共编码结构；不创建额外的数据存储实例。
import Foundation

struct QueryCacheEnvelope<Item: Codable>: Codable
{
    let items: [Item]
    let updatedAt: Date
}
