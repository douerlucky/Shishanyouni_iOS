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
        .optionalLiquidGlass(
            in: RoundedRectangle(cornerRadius: 20, style: .continuous),
            fallback: Color(uiColor: .secondarySystemBackground)
        )
    }
}
