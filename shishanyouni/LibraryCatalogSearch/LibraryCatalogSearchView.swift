//
//  LibraryCatalogSearchView.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/9/27.
//

import SwiftUI

struct CategoryCard: View
{
    let title: String
    let author: String
    let information: String

    var body: some View
    {
        VStack(alignment: .leading, spacing: 10)
        {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)

            HStack(alignment: .firstTextBaseline, spacing: 8)
            {
                Text("作者")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 42, alignment: .leading)

                Text(author.isEmpty ? "暂无作者信息" : author)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8)
            {
                Text("出版信息")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 64, alignment: .leading)

                Text(information.isEmpty ? "暂无出版信息" : information)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            .thinMaterial,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .optionalLiquidGlass(
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }
}

struct LibraryCatalogSearchView: View
{
    @State private var isLoading = false
    @State private var keyword = "" // 关键词
    @State private var searchType: SearchType = .anyWord // 搜索类型

    @State private var bookList: [Book] = [] // 返回的Book
    @State private var hasSearched = false // 是否搜索到
    @State private var errorMessage: String?

    @State private var currentPage = 0 //当前页面
    @State private var totalCount = 0 //所有页面总数
    @State private var isLoadingNextPage = false

    @State private var activeKeyword = ""
    @State private var activeSearchType: SearchType = .anyWord
    @State private var loadMoreError: String?
    var body: some View
    {
        NavigationStack
        {
            ZStack
            {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 16)
                {
                    Picker("检索方式", selection: $searchType)
                    {
                        Text("任意词").tag(SearchType.anyWord)
                        Text("书名").tag(SearchType.title)
                        Text("作者").tag(SearchType.author)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    ScrollView
                    {
                        if isLoading
                        {
                            ProgressView("正在检索馆藏…")
                                .padding(.top, 48)
                        }
                        else if let errorMessage
                        {
                            Text(errorMessage)
                                .foregroundStyle(.secondary)
                                .padding(.top, 48)
                        }
                        else if hasSearched && bookList.isEmpty
                        {
                            Text("尚未找到任何书籍")
                                .foregroundStyle(.secondary)
                                .padding(.top, 48)
                        }
                        else
                        {
                            LazyVStack(spacing: 12)
                            {
                                ForEach(bookList)
                                { book in
                                    NavigationLink
                                    {
                                        LibraryCategoryDetailView(rd: book.rd, no: book.no)
                                    }
                                    label:
                                    {
                                        CategoryCard(
                                            title: book.name,
                                            author: book.author,
                                            information: book.publish
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                                if isLoadingNextPage
                                {
                                    ProgressView("正在加载更多…")
                                        .padding(.vertical)
                                }
                                else if loadMoreError != nil
                                {
                                    Button("加载失败，点此重试")
                                    {
                                        Task
                                        {
                                            await loadNextPage()
                                        }
                                    }
                                    .padding(.vertical)
                                }
                                else if canLoadNextPage
                                {
                                    Color.clear
                                        .frame(height: 1)
                                        .onAppear
                                        {
                                            Task
                                            {
                                                await loadNextPage()
                                            }
                                        }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("馆藏检索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            // 使用系统搜索栏：iOS 26 会自动采用液态玻璃外观。
            .searchable(
                text: $keyword,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "输入书名、作者或关键词"
            )
            .onSubmit(of: .search)
            {
                Task { await searchBooks() }
            }
        }
    }

    //判断能否加入下一页
    private var canLoadNextPage: Bool
    {
        hasSearched
            && !isLoading
            && !isLoadingNextPage
            && currentPage > 0
            && bookList.count < totalCount
    }

    //判断是否还有下一页
    private var hasMorePages: Bool
    {
        bookList.count < totalCount
    }

    @MainActor
    private func searchBooks() async
    {
        currentPage = 0
        totalCount = 0
        loadMoreError = nil

        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedKeyword.isEmpty
        else
        {
            errorMessage = "请输入检索关键词。"
            return
        }

        isLoading = true
        errorMessage = nil
        hasSearched = false
        bookList = []

        defer { isLoading = false }

        do
        {
            let service = LibraryCatalogSearch()

            let result = try await service.search(
                keyword: trimmedKeyword,
                searchType: searchType
            )

            bookList = result.bookList
            currentPage = result.page
            totalCount = result.totalCnt
            activeKeyword = trimmedKeyword
            activeSearchType = searchType
            hasSearched = true
        }
        catch
        {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadNextPage() async
    {
        guard canLoadNextPage else
        {
            return
        }

        isLoadingNextPage = true
        loadMoreError = nil

        defer { isLoadingNextPage = false }

        do
        {
            let service = LibraryCatalogSearch()

            let result = try await service.search(
                keyword: activeKeyword,
                searchType: activeSearchType,
                page: currentPage + 1
            )

            // 后端若意外返回空页，停止继续请求，避免无限触发加载。
            guard !result.bookList.isEmpty else
            {
                totalCount = bookList.count
                return
            }

            bookList.append(contentsOf: result.bookList)
            currentPage = result.page
            totalCount = result.totalCnt
        }
        catch
        {
            // 不使用 errorMessage，否则会把已显示的第一页列表整个替换掉。
            loadMoreError = error.localizedDescription
        }
    }
}

#Preview
{
    LibraryCatalogSearchView()
}
