import SwiftUI

/// 兼容项目当前的最低 iOS 版本的空状态视图。
struct DetailEmptyState: View
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

struct BookInformationCard: View
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
        .optionalLiquidGlass(
            in: RoundedRectangle(cornerRadius: 20, style: .continuous),
            fallback: Color(uiColor: .secondarySystemBackground)
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

struct LibraryBookSiteCard: View
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
        .optionalLiquidGlass(
            in: RoundedRectangle(cornerRadius: 18, style: .continuous),
            fallback: Color(uiColor: .secondarySystemBackground)
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
