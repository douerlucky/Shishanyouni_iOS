import SwiftUI

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

#Preview
{
    AllStrategy()
}
