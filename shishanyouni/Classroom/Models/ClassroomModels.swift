import Foundation

// 空教室接口响应位于 Classroom/Models/ClassroomAPIModels.swift。

// MARK: - 渲染模型

struct RoomStatus: Identifiable
{
    let id = UUID()
    /// 0-based 数组下标（与 API 返回的 data 数组对应）
    let arrayIndex: Int
    let slots: [Int]        // 长度为5：1-2节, 3-4节, 5-6节, 7-8节, 9-12节 (0空闲/1占用)
}
