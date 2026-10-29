//
//  Course.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/10.
//  Updated by lancang on 2026/3/15 手动添加课程功能

import Foundation

// MARK: - 响应结构体

//struct ScheduleResponse: Decodable
//{
//    let kbList: [Course]
//}

// MARK: - 课程结构体

//struct Course: Identifiable, Decodable, Encodable
//{
//    let jxb_id: String // 教学班ID（唯一标识）
//    let kch_id: String // 课程ID
//    let kcmc: String // 课程名称
//    let xqj: String // 星期几（1-7）
//    let jcs: String // 节次（如"5-8"）
//    let cdmc: String? // 教室名称
//    let xm: String? // 教师姓名
//    let zcmc: String? // 教师职称
//    let jxbzc: String? // 上课班级（分号分隔）
//    let zcd: String? // 周次（如"4-5周,7-8周"）
//    let xqjmc: String? // 星期几中文（如"星期一"）
//
//    var colorIndex: Int? = 0 //用于固定保存颜色的索引
//
//    // 是否为手动添加的课程
//    var isManual: Bool = false
//
//    enum CodingKeys: String, CodingKey {
//        case jxb_id, kch_id, kcmc, xqj, jcs, cdmc, xm, zcmc, jxbzc, zcd, xqjmc, colorIndex
//    }
//    // 需要添加：自定义解码器
//    init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//
//        jxb_id = try container.decode(String.self, forKey: .jxb_id)
//        kch_id = try container.decode(String.self, forKey: .kch_id)
//        kcmc = try container.decode(String.self, forKey: .kcmc)
//        xqj = try container.decode(String.self, forKey: .xqj)
//        jcs = try container.decode(String.self, forKey: .jcs)
//        cdmc = try container.decodeIfPresent(String.self, forKey: .cdmc)
//        xm = try container.decodeIfPresent(String.self, forKey: .xm)
//        zcmc = try container.decodeIfPresent(String.self, forKey: .zcmc)
//        jxbzc = try container.decodeIfPresent(String.self, forKey: .jxbzc)
//        zcd = try container.decodeIfPresent(String.self, forKey: .zcd)
//        xqjmc = try container.decodeIfPresent(String.self, forKey: .xqjmc)
//        colorIndex = try container.decodeIfPresent(Int.self, forKey: .colorIndex)
//
//        // 从服务器导入的课程，isManual 始终为 false
//        isManual = false
//    }
//    // 明确的成员初始化方法
//    init(jxb_id: String,
//         kch_id: String,
//         kcmc: String,
//         xqj: String,
//         jcs: String,
//         cdmc: String?,
//         xm: String?,
//         zcmc: String?,
//         jxbzc: String?,
//         zcd: String?,
//         xqjmc: String?,
//         colorIndex: Int? = nil,
//         isManual: Bool = false) {
//        self.jxb_id = jxb_id
//        self.kch_id = kch_id
//        self.kcmc = kcmc
//        self.xqj = xqj
//        self.jcs = jcs
//        self.cdmc = cdmc
//        self.xm = xm
//        self.zcmc = zcmc
//        self.jxbzc = jxbzc
//        self.zcd = zcd
//        self.xqjmc = xqjmc
//        self.colorIndex = colorIndex
//        self.isManual = isManual
//    }
//    // 需要添加：自定义编码器
//    func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//
//        try container.encode(jxb_id, forKey: .jxb_id)
//        try container.encode(kch_id, forKey: .kch_id)
//        try container.encode(kcmc, forKey: .kcmc)
//        try container.encode(xqj, forKey: .xqj)
//        try container.encode(jcs, forKey: .jcs)
//        try container.encodeIfPresent(cdmc, forKey: .cdmc)
//        try container.encodeIfPresent(xm, forKey: .xm)
//        try container.encodeIfPresent(zcmc, forKey: .zcmc)
//        try container.encodeIfPresent(jxbzc, forKey: .jxbzc)
//        try container.encodeIfPresent(zcd, forKey: .zcd)
//        try container.encodeIfPresent(xqjmc, forKey: .xqjmc)
//        try container.encodeIfPresent(colorIndex, forKey: .colorIndex)
//
//        // 注意：不编码 isManual，因为它不需要保存到服务器
//    }
//    // 使用教学班ID作为唯一标识
//    var id: String
//    {
//        if isManual {
//            return jxb_id
//        }
//        return jxb_id
//    }
//
//    // 计算属性：格式化的节次显示
//    var formattedJcs: String
//    {
//        "第\(jcs)节"
//    }
//
//    // 计算属性：班级列表
//    var classList: [String]
//    {
//        jxbzc?.components(separatedBy: ";") ?? []
//    }
//
//    var parsedWeeks: Set<Int>
//    {
//        guard let zcd = zcd else { return Set() }
//
//        var result = Set<Int>()
//
//        // 去掉"周"，按逗号分割成各个部分
//        let segments = zcd.replacingOccurrences(of: "周", with: "").components(separatedBy: ",")
//
//        for segment in segments
//        {
//            let trimmed = segment.trimmingCharacters(in: .whitespaces)
//
//            // 检查是否包含单双周标记
//            let isSingleWeek = trimmed.contains("(单)") || trimmed.contains("（单）")
//            let isDoubleWeek = trimmed.contains("(双)") || trimmed.contains("（双）")
//
//            // 移除单双周标记，提取数字部分
//            let cleanSegment = trimmed
//                .replacingOccurrences(of: "(单)", with: "")
//                .replacingOccurrences(of: "（单）", with: "")
//                .replacingOccurrences(of: "(双)", with: "")
//                .replacingOccurrences(of: "（双）", with: "")
//                .trimmingCharacters(in: .whitespaces)
//
//            if cleanSegment.contains("-")
//            {
//                // 处理范围格式 "8-9"、"13-17(单)"、"6-10(双)" 等
//                let parts = cleanSegment.components(separatedBy: "-")
//                if parts.count == 2,
//                   let start = Int(parts[0].trimmingCharacters(in: .whitespaces)),
//                   let end = Int(parts[1].trimmingCharacters(in: .whitespaces))
//                {
//                    for w in start ... end
//                    {
//                        // 如果有单周标记，只添加奇数周
//                        if isSingleWeek && w % 2 == 1
//                        {
//                            result.insert(w)
//                        }
//                        // 如果有双周标记，只添加偶数周
//                        else if isDoubleWeek && w % 2 == 0
//                        {
//                            result.insert(w)
//                        }
//                        // 没有单双周标记，添加所有周
//                        else if !isSingleWeek && !isDoubleWeek
//                        {
//                            result.insert(w)
//                        }
//                    }
//                }
//            }
//            else if let singleWeek = Int(cleanSegment)
//            {
//                // 处理单周格式 "5"、"12"、"18" 等
//                // 单周或没有标记都直接添加
//                result.insert(singleWeek)
//            }
//        }
//        return result
//    }
//}
//// 新增：手动课程创建辅助办法
//extension Course {
//    static func createManualCourse(
//        name: String,
//        weekday: Int,
//        startPeriod: Int,
//        endPeriod: Int,
//        weeks: Set<Int>,
//        location: String? = nil,
//        teacher: String? = nil
//    ) -> Course {
//        // 生成唯一ID
//        let id = "manual_\(UUID().uuidString)"
//
//        // 格式化节次
//        let jcsString = "\(startPeriod)-\(endPeriod)"
//
//        // 格式化周次
//        let weeksString = weeks.sorted().map { "\($0)" }.joined(separator: ",") + "周"
//
//        return Course(
//            jxb_id: id,
//            kch_id: id,
//            kcmc: name,
//            xqj: "\(weekday)",
//            jcs: jcsString,
//            cdmc: location,
//            xm: teacher,
//            zcmc: nil,
//            jxbzc: nil,
//            zcd: weeksString,
//            xqjmc: nil,
//            colorIndex: Int.random(in: 0...31), // 随机颜色
//            isManual: true
//        )
//    }
//}
// MARK: - 课表查询类
