//
//  FunMessage.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/3/31.
//

import Foundation

struct FunMessage {
    
    /// 获取根据日期和用户信息生成的随机寄语
    static func getDailyMessage(for user: userInfo) -> String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date()) // 1是周日, 2是周一...
        
        // 获取用户称呼：优先昵称，其次学号
        let displayName = user.username
        
        let messages: [Int: [String]] = [
            2: [
                "\(displayName)，周一也要元气满满！",
                "又是新的一周，继续努力哦！",
                "又要上课了！哎~"
            ],
            3: [
                "周二了，要不要去跑跑南湖跑？",
                "只要努力，梦想一定会实现！",
                "要不要\(displayName)点个外卖？"
            ],
            4: [
                "周三过半，胜利在望！加油 \(displayName)！",
                "今天去不去自习呢？",
                "周三日常课多..."
            ],
            5: [
                "周四了！KFC疯狂星期四！",
                "华农的猫猫今天也在等你投喂哦，\(displayName)。",
                "Today is Thursday"
            ],
            6: [
                "周五啦！今晚可以刷手机刷到深夜吗？",
                "这一周辛苦了，\(displayName)",
                "准备迎接周末的快了吧！"
            ],
            7: [
                "周六！独属于自己的治愈时间。",
                "南湖边散散步，或者去武汉市中心转转？",
                "休息是为了走更远的路，祝 \(displayName) 周末愉快。"
            ],
            1: [
                "周日，该收收心准备下周的课了。",
                "明天又是早八，不想上课!",
                "今天在华农的小孩是不是都该回家了。"
            ]
        ]
        
        // 随机返回一条对应星期的文案
        return messages[weekday]?.randomElement() ?? "今天也要加油哦！"
    }
}
