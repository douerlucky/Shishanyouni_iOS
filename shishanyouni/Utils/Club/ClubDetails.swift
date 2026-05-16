//
//  ClubDetailView.swift
//  shishanyouni
//

import SwiftUI

// MARK: - Model

struct ClubDetail: Identifiable, Decodable
{
    let id: Int
    let name: String
    let avatar: String
    let introduction: String?
    let contact: [String]?
    let nameIndex: String?
}

struct ClubDetailResponse: Decodable
{
    let msg: String
    let code: Int
    let data: ClubDetail
    let success: Bool
}

// MARK: - ViewModel

@MainActor
class ClubDetailViewModel: ObservableObject
{
    @Published var detail: ClubDetail?
    @Published var isLoading = true
    @Published var errorMessage: String?

    func fetch(id: Int) async
    {
        guard let url = URL(string: "https://lion.hzau.edu.cn//app/ios/v2/club/getbyid?id=\(id)") else { return }
        do
        {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ClubDetailResponse.self, from: data)
            detail = response.data
        }
        catch
        {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
        isLoading = false
    }
}

// MARK: - View

struct ClubDetailView: View
{
    let clubId: Int
    @StateObject private var viewModel = ClubDetailViewModel()

    var body: some View
    {
        Group
        {
            if viewModel.isLoading
            {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            else if let err = viewModel.errorMessage
            {
                VStack(spacing: 16)
                {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary)
                    Text(err)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Button("重试") { Task { await viewModel.fetch(id: clubId) } }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            else if let club = viewModel.detail
            {
                ScrollView
                {
                    VStack(spacing: 0)
                    {
                        // —— Logo ——
                        AsyncImage(url: URL(string: club.avatar))
                        { phase in
                            switch phase
                            {
                            case let .success(image):
                                image.resizable().scaledToFill()
                            case .failure:
                                Image(systemName: "person.3.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(Color(.systemGray5))
                            case .empty:
                                ProgressView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(Color(.systemGray6))
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .stroke(Color(.systemGray4), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        .padding(.top, 28)

                        Text(club.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.top, 14)
                            .padding(.bottom, 4)

                        // —— 简介 ——
                        if let intro = club.introduction, !intro.isEmpty
                        {
                            DetailSection(title: "社团简介", icon: "text.alignleft")
                            {
                                Text(intro)
                                    .font(.system(size: 15))
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineSpacing(5)
                            }
                        }

                        // —— 联系方式 ——
                        if let contacts = club.contact, !contacts.isEmpty {
                            DetailSection(title: "联系方式", icon: "bubble.left.and.bubble.right") {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(contacts, id: \.self) { item in
                                        Button {
                                            // 【核心修改点】：通过 filter 只保留数字部分
                                            let numbersOnly = item.filter { $0.isNumber }
                                            
                                            // 只有当过滤后不为空时才执行复制，防止误触
                                            if !numbersOnly.isEmpty {
                                                UIPasteboard.general.string = numbersOnly
                                                
                                                // 触感反馈
                                                let impactMed = UIImpactFeedbackGenerator(style: .medium)
                                                impactMed.impactOccurred()
                                            }
                                        } label: {
                                            HStack(spacing: 8) {
                                                Image(systemName: "link")
                                                    .font(.caption)
                                                    .foregroundColor(.accentColor)
                                                Text(item) // 界面上依然显示完整信息（如“QQ群：12345”），方便阅读
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.primary)
                                                    .multilineTextAlignment(.leading)
                                                
                                                Spacer()
                                                
                                                Text("复制群号")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color(.systemGray5))
                                                    .clipShape(Capsule())
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .navigationTitle(viewModel.detail?.name ?? "社团详情")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.fetch(id: clubId) }
    }
}

// MARK: - Section Card

struct DetailSection<Content: View>: View
{
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View
    {
        VStack(alignment: .leading, spacing: 12)
        {
            HStack(spacing: 6)
            {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.bottom, 14)
    }
}

// MARK: - Preview

#Preview
{
    NavigationView
    {
        ClubDetailView(clubId: 1)
    }
}
