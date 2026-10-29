import Foundation

//
//  ElectricityAPIModels.swift
//  shishanyouni
//
//  电费余额、电表与楼栋 / 楼层 / 房间选择器接口的响应。
//  这里只定义接口的数据格式；请求执行、错误处理和界面状态留在业务模块。
//


// MARK: - 电费响应数据结构

struct ElectricityResponse: Decodable
{
    let code: Int
    let msg: String
    let data: ElectricityPageData?
}

struct ElectricityPageData: Decodable
{
    let records: [ElectricityRecord]
}

struct ElectricityRecord: Identifiable, Decodable
{
    var id: String { roomId }

    let roomId: String // 房间ID
    let roomName: String // 房间名 (如: 荟01-101)
    let accountAddress: String // 详细地址 (如: 荟01栋-101)
    let balance: String // 余额 (核心字段)
    let eleAmount: String? // 电费单价/金额相关
    let roomTypeName: String? // 房间类型 (如: 本科生)

    // 嵌套的电表详情
    let baseMeterList: [MeterDetail]?

    // 计算属性：获取最新的读数时间
    var lastUpdate: String
    {
        baseMeterList?.first?.lastReadingTime ?? "未知"
    }
}

struct MeterDetail: Decodable
{
    let meterCode: String // 电表号
    let lastReading: Double? // 最后一次抄表读数
    let lastReadingTime: String? // 抄表时间
}

// MARK: - 通用选择器模型 (用于楼栋、楼层、房间列表)

struct BuildingLevelRoomResponse: Decodable
{
    let code: Int
    let msg: String
    let data: PickerData?

    // 有些接口直接返回 data 数组，有些返回 data 对象里包含 records
    enum PickerData: Decodable
    {
        case array([PickerItem])
        case object(PageRecords)

        init(from decoder: Decoder) throws
        {
            let container = try decoder.singleValueContainer()
            if let array = try? container.decode([PickerItem].self)
            {
                self = .array(array)
            }
            else if let object = try? container.decode(PageRecords.self)
            {
                self = .object(object)
            }
            else
            {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode PickerData")
            }
        }
    }

    struct PageRecords: Decodable
    {
        let records: [PickerItem]
    }
}

struct PickerItem: Decodable, Identifiable
{
    var id: String { value }
    let label: String // 显示文本 (如: 荟01栋, 1层, 101)
    let value: String // 传参值 (如: 1770694614656974850)
}
