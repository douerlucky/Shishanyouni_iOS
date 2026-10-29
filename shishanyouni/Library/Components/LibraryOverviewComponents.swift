import SwiftUI

struct StatItem: View
{
    let value: String
    let label: String
    let color: Color

    var body: some View
    {
        VStack(spacing: 6)
        {
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct RuleRow: View
{
    let icon: String
    let text: String

    var body: some View
    {
        HStack(spacing: 8)
        {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }
}

#Preview
{
    NavigationStack
    {
        LibraryOverviewView()
            .environmentObject(userInfo())
    }
}
