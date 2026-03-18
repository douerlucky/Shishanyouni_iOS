//
//  AboutUs.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/3/16.
//

import SwiftUI

struct AboutUs: View {
    var body: some View {
        // 使用ScrollView适配内容过长的情况
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                // 顶部Logo和标题
                Image("login")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 128, height: 128)
                    .cornerRadius(32)
                
                Text("关于狮山有你iOS版")
                    .font(.title)
                    .fontWeight(.bold)
                
                // 核心信息表格区（仿系统设置的表格样式）
                VStack(spacing: 0) {
                    // 表格行1：版本号
                    infoRow(title: "当前版本", content: "0.1 beta 4")
                    
                    // 分割线
                    Divider()
                    
                    // 表格行2：构建时间
                    infoRow(title: "构建时间", content: "2026年3月18日")
                    
                    // 分割线
                    Divider()
                    
                    infoRow(title: "内测反馈群（长按可复制）", content: "1090311516")
                        .contextMenu {
                            // 长按复制功能
                            Button("复制群号") {
                                UIPasteboard.general.string = "1090311516"
                            }
                        }
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                .padding(.horizontal, 16)
                
                // 开发/设计信息区
                VStack(alignment: .leading, spacing: 8) {
                    Text("开发团队")
                        .font(.headline)
                    
                    Text("沸点工作室 移动App开发组")
                    Text("iOS版UI设计：douer_lucky")
                    Text("iOS版开发：douer_lucky、澜沧")

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
                VStack(alignment: .leading, spacing: 16) {
                    
                    Text("狮山有你是一个专为华中农业大学师生打造的校园工具，提供了课表、考试安排、成绩和空教室等多种查询功能。通过狮山有你，你可以更好地管理学业和校园生活，提高学习效率，让校园生活更加便捷和有序。无论是学生还是教师，狮山有你都将成为你不可或缺的校园伙伴。")
                        .lineSpacing(4)
                    
                    
                    Text("狮山有你工作室是由一群具有奉献精神的学生建立的学生工作室，负责狮山有你的开发和维护，工作室秉承“学以致用，服务同学”的理念，致力于为华农学子提供安全可靠、简单好用、界面美观的移动端一站式信息获取平台。")
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
    
    
    private func infoRow(title: String, content: String) -> some View {
        HStack {
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
#Preview {
    AboutUs()
}
