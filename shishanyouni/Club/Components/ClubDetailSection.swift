import SwiftUI

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
