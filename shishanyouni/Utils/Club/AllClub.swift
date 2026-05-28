//
//  AllClub.swift
//  shishanyouni
//

import SwiftUI

// MARK: - Models

struct Club: Identifiable, Decodable
{
    let id: Int
    let name: String
    let avatar: String
    let introduction: String?
    let contact: String?
    let nameIndex: String?
}

struct ClubListResponse: Decodable
{
    let msg: String
    let code: Int
    let data: [[Club]]
    let success: Bool
}

// MARK: - ViewModel

@MainActor
class AllClubViewModel: ObservableObject
{
    @Published var groupedClubs: [(letter: String, clubs: [Club])] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    private let letters: [String] = (65 ... 90).map { String(UnicodeScalar($0)!) }

    func fetchClubs() async
    {
        guard let url = URL(string: "https://lion.hzau.edu.cn/app/ios/club/getall") else { return }
        do
        {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ClubListResponse.self, from: data)
            groupedClubs = zip(letters, response.data).compactMap
            { letter, clubs in
                clubs.isEmpty ? nil : (letter: letter, clubs: clubs)
            }
        }
        catch
        {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
        isLoading = false
    }

    func filtered(by query: String) -> [(letter: String, clubs: [Club])]
    {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return groupedClubs }
        return groupedClubs.compactMap
        { item in
            let matched = item.clubs.filter { $0.name.localizedCaseInsensitiveContains(query) }
            return matched.isEmpty ? nil : (letter: item.letter, clubs: matched)
        }
    }
}

// MARK: - Main View

struct AllClub: View
{
    @StateObject private var viewModel = AllClubViewModel()
    @State private var searchText = ""

    var displayGroups: [(letter: String, clubs: [Club])]
    {
        viewModel.filtered(by: searchText)
    }

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
                        ProgressView().scaleEffect(1.4)
                        Text("加载社团列表…")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
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
                        Button("重试") { Task { await viewModel.fetchClubs() } }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                else
                {
                    ClubIndexList(groups: displayGroups, searchText: searchText)
                        .searchable(
                            text: $searchText,
                            placement: .navigationBarDrawer(displayMode: .always),
                            prompt: "搜索社团名称"
                        )
                }
            }
            .navigationTitle("全部社团")
            .navigationBarTitleDisplayMode(.large)
            .toolbar(.hidden, for: .tabBar)
        }
        .navigationViewStyle(.stack)
        .task { await viewModel.fetchClubs() }
    }
}

// MARK: - List + Index Bar

struct ClubIndexList: View
{
    let groups: [(letter: String, clubs: [Club])]
    let searchText: String

    var presentLetters: [String] { groups.map(\.letter) }

    var body: some View
    {
        ScrollViewReader
        { proxy in
            ZStack(alignment: .trailing)
            {
                List
                {
                    if groups.isEmpty
                    {
                        ContentUnavailableRow(query: searchText)
                    }
                    else
                    {
                        ForEach(groups, id: \.letter)
                        { item in
                            Section
                            {
                                ForEach(item.clubs)
                                { club in
                                    NavigationLink(destination: ClubDetailView(clubId: club.id))
                                    {
                                        ClubRow(club: club)
                                    }
                                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                                }
                            } header: {
                                Text(item.letter)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .id(item.letter)
                        }
                    }
                }
                .listStyle(.plain)

                if searchText.isEmpty
                {
                    IndexSidebar(letters: presentLetters, proxy: proxy)
                        .padding(.trailing, 2)
                }
            }
        }
    }
}

// MARK: - Sidebar Index

struct IndexSidebar: View
{
    let letters: [String]
    let proxy: ScrollViewProxy
    @GestureState private var dragLetter: String? = nil

    var body: some View
    {
        VStack(spacing: 0)
        {
            ForEach(letters, id: \.self)
            { letter in
                Text(letter)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(dragLetter == letter ? .white : .accentColor)
                    .frame(width: 22, height: 18)
                    .background(
                        Group
                        {
                            if dragLetter == letter
                            {
                                Circle().fill(Color.accentColor)
                            }
                            else
                            {
                                Color.clear
                            }
                        }
                    )
            }
        }
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground).opacity(0.9))
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        )
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .updating($dragLetter)
                { value, state, _ in
                    let itemHeight: CGFloat = 18
                    let index = max(0, min(letters.count - 1, Int(value.location.y / itemHeight)))
                    let letter = letters[index]
                    state = letter
                    DispatchQueue.main.async
                    {
                        withAnimation(.none) { proxy.scrollTo(letter, anchor: .top) }
                    }
                }
        )
    }
}

// MARK: - Club Row

struct ClubRow: View
{
    let club: Club

    var body: some View
    {
        HStack(spacing: 12)
        {
            AsyncImage(url: URL(string: club.avatar))
            { phase in
                switch phase
                {
                case let .success(image):
                    image.resizable().scaledToFill()
                case .failure:
                    Image(systemName: "person.3.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 20))
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
            .frame(width: 46, height: 46)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )

            VStack(alignment: .leading, spacing: 2)
            {
                Text(club.name)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                if let intro = club.introduction, !intro.isEmpty
                {
                    Text(intro)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Empty State

struct ContentUnavailableRow: View
{
    let query: String
    var body: some View
    {
        VStack(spacing: 12)
        {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("未找到\(query)相关社团")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .listRowSeparator(.hidden)
    }
}

// MARK: - Preview

#Preview
{
    AllClub()
}
