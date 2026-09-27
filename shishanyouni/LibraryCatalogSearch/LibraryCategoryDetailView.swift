//
//  LibraryCategoryDetailView.swift
//  shishanyouni
//

import SwiftUI

struct LibraryCategoryDetailView: View
{
    /// 列表页传入的字段，也是详情接口唯一需要的参数。
    let rd: String
    let no: String

    @State private var detail: LibraryCategoryDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View
    {
        ZStack
        {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            if isLoading
            {
                ProgressView("正在获取图书详情…")
            }
            else if let errorMessage
            {
                DetailEmptyState(
                    title: "详情获取失败",
                    systemImage: "exclamationmark.triangle",
                    message: errorMessage
                )
                .overlay(alignment: .bottom)
                {
                    Button("重试")
                    {
                        Task { await loadDetail() }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 48)
                }
            }
            else if let detail
            {
                ScrollView
                {
                    VStack(alignment: .leading, spacing: 20)
                    {
                        BookInformationCard(detail: detail)

                        HStack
                        {
                            Text("馆藏副本")
                                .font(.title3.bold())

                            Spacer()

                            Text("共 \(detail.siteList.count) 本")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if detail.siteList.isEmpty
                        {
                            DetailEmptyState(
                                title: "暂无馆藏副本",
                                systemImage: "books.vertical"
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                        }
                        else
                        {
                            LazyVGrid(columns: columns, spacing: 12)
                            {
                                ForEach(detail.siteList)
                                { site in
                                    LibraryBookSiteCard(site: site)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("图书详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task
        {
            await loadDetail()
        }
    }

    @MainActor
    private func loadDetail() async
    {
        isLoading = true
        errorMessage = nil

        defer
        {
            isLoading = false
        }

        do
        {
            detail = try await LibraryCategoryDetailService().fetchDetail(rd: rd, no: no)
        }
        catch
        {
            errorMessage = error.localizedDescription
        }
    }
}

/// 兼容项目当前的最低 iOS 版本的空状态视图。
private struct DetailEmptyState: View
{
    let title: String
    let systemImage: String
    var message: String?

    var body: some View
    {
        VStack(spacing: 10)
        {
            Image(systemName: systemImage)
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            if let message
            {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

private struct BookInformationCard: View
{
    let detail: LibraryCategoryDetail

    var body: some View
    {
        VStack(alignment: .leading, spacing: 12)
        {
            Text(detail.title)
                .font(.title2.bold())
                .foregroundStyle(.primary)

            BookDetailLine(label: "作者", value: detail.author)
            BookDetailLine(label: "出版社", value: detail.publisher)
            BookDetailLine(label: "ISBN", value: detail.isbn)
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

private struct BookDetailLine: View
{
    let label: String
    let value: String

    var body: some View
    {
        HStack(alignment: .firstTextBaseline, spacing: 8)
        {
            Text("\(label)：")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: 72, alignment: .leading)

            Text(value.isEmpty ? "暂无信息" : value)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
    }
}

private struct LibraryBookSiteCard: View
{
    let site: LibraryBookSite

    var body: some View
    {
        VStack(alignment: .leading, spacing: 10)
        {
            Label(
                site.status,
                systemImage: site.isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill"
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(site.isAvailable ? .green : .secondary)

            SiteInformation(label: "房间", value: site.room)
            SiteInformation(label: "详细位置", value: site.location)
            SiteInformation(label: "编码", value: site.number)
        }
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .topLeading)
        .padding(14)
        .background(
            .thinMaterial,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .optionalLiquidGlass(
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }
}

private struct SiteInformation: View
{
    let label: String
    let value: String

    var body: some View
    {
        VStack(alignment: .leading, spacing: 2)
        {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value.isEmpty ? "暂无信息" : value)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
    }
}

#Preview
{
    NavigationStack
    {
        LibraryCategoryDetailView(rd: "KWDG44E7J9", no: "556627")
    }
}
