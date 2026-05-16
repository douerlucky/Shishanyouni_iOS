//
//  AllStrategy.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/3/30.
//

import SwiftUI

// MARK: - 数据模型

struct Guide: Codable, Identifiable
{
    let id: Int
    let name: String
    let icon: String?
    let context: String?
    let author: String?
    let time: String?
}

struct GuideResponse: Codable
{
    let msg: String
    let code: Int
    let data: [Guide]?
}

// MARK: - ViewModel

class AllStrategyViewModel: ObservableObject
{
    @Published var guides: [Guide] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    func fetchGuides()
    {
        guard let url = URL(string: "https://lion.hzau.edu.cn/app/ios/v2/guide/getinfo") else { return }

        isLoading = true
        errorMessage = nil

        URLSession.shared.dataTask(with: url)
        { data, _, error in
            DispatchQueue.main.async
            {
                self.isLoading = false

                if let error = error
                {
                    self.errorMessage = "请求失败：\(error.localizedDescription)"
                    return
                }

                guard let data = data
                else
                {
                    self.errorMessage = "无数据返回"
                    return
                }

                do
                {
                    let result = try JSONDecoder().decode(GuideResponse.self, from: data)
                    self.guides = result.data ?? []
                }
                catch
                {
                    self.errorMessage = "数据解析失败：\(error.localizedDescription)"
                }
            }
        }.resume()
    }
}

// MARK: - 单个攻略卡片

struct GuideCard: View
{
    let guide: Guide

    var body: some View
    {
        VStack(spacing: 8)
        {
            AsyncImage(url: URL(string: guide.icon ?? ""))
            { phase in
                switch phase
                {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFit()
                case .failure:
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.gray)
                case .empty:
                    ProgressView()
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 36, height: 36)
            .padding(24)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 24))

            Text(guide.name)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

// MARK: - 主视图

struct AllStrategy: View
{
    @StateObject private var viewModel = AllStrategyViewModel()

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    var body: some View
    {
        NavigationView
        {
            Group
            {
                if viewModel.isLoading
                {
                    VStack(spacing: 16)
                    {
                        ProgressView()
                            .scaleEffect(1.4)
                        Text("加载中...")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                }
                else if let error = viewModel.errorMessage
                {
                    VStack(spacing: 16)
                    {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(error)
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("重新加载")
                        {
                            viewModel.fetchGuides()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                else if viewModel.guides.isEmpty
                {
                    VStack(spacing: 16)
                    {
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("暂无攻略")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                }
                else
                {
                    ScrollView
                    {
                        LazyVGrid(columns: columns, spacing: 12)
                        {
                            ForEach(viewModel.guides)
                            { guide in
                                NavigationLink(destination: StrategyDetailView(guideId: guide.id))
                                {
                                    GuideCard(guide: guide)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("校园攻略")
            .toolbar(.hidden, for: .tabBar)
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear
        {
            viewModel.fetchGuides()
        }
    }
}

#Preview
{
    AllStrategy()
}
