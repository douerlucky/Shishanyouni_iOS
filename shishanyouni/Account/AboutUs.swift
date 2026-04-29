//
//  AboutUs.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/3/16.
//

import SwiftUI

struct AboutUs: View
{
    var body: some View
    {
        // 使用ScrollView适配内容过长的情况
        ScrollView(.vertical, showsIndicators: false)
        {
            VStack(spacing: 16)
            {
                // 顶部Logo和标题
                Image("login")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 128, height: 128)
                    .cornerRadius(32)

                Text("关于狮山有你iOS版")
                    .font(.title)
                    .fontWeight(.bold)

                // 开发/设计信息区
                VStack(alignment: .leading, spacing: 8)
                {
                    Text("开发团队")
                        .font(.headline)

                    Text("沸点工作室 移动App开发组")
                    Text("iOS版UI设计：douer_lucky")
                    Text("iOS版开发：douer_lucky、澜沧")

                    Text("版本 1.1.1")
                    Text("反馈QQ群聊（长按复制）：1090311516")
                        .textSelection(.enabled)
                        .onTapGesture
                        {
                            UIPasteboard.general.string = "1090311516"
                        }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                .padding(.horizontal, 16)

                Text("部分后端数据由狮山有你工作室提供")
                    .foregroundColor(.gray)

                // 简介和工作室说明
                VStack(alignment: .leading, spacing: 16)
                {
                    Text("狮山有你 iOS 是一款校园信息与学习生活工具应用，提供课表管理、课程查询、考试信息、空教室、校历、校车、校园攻略与社团信息等功能。部分个性化服务可在用户自愿登录其校园账号后使用，其余公开内容与本地工具功能无需登录也可体验。")
                        .lineSpacing(4)

                    Text("沸点工作室移动 App 开发组 & Swift Coding Club HZAU 是一个专注于移动应用设计与开发的团队，持续进行 UI 交互设计、iOS 开发与相关技术实践。")

                    Text("狮山有你 iOS 由独立开发者与学生团队持续维护。我们希望通过清晰、可靠、易用的产品设计，整理校园公开信息，并为有需要的用户提供便捷的移动端信息查询与学习生活辅助体验。")
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                .padding(.horizontal, 16)

                // 底部留白
                Spacer(minLength: 32)
            }
            .padding(.vertical, 24)
        }
        .background(Color(.systemGray6))
        .toolbar(.hidden, for: .tabBar)
    }

    private func infoRow(title: String, content: String) -> some View
    {
        HStack
        {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary) // 标题灰色，次要信息
            Spacer()
            Text(content)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// 预览
#Preview
{
    AboutUs()
}
