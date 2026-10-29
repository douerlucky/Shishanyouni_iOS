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
                    .nativeGlassButtonStyle(prominent: true)
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
            detail = try await LibraryCategoryDetailAPI().fetchDetail(rd: rd, no: no)
        }
        catch
        {
            errorMessage = error.localizedDescription
        }
    }
}
