import SwiftUI
import UIKit
import WebKit

// MARK: - WebView 包装

struct SchoolCalendarWeb: UIViewRepresentable
{
    let urlString: String

    func makeUIView(context: Context) -> WKWebView
    {
        let webView = WKWebView()
        webView.allowsBackForwardNavigationGestures = true
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context)
    {
        guard let url = URL(string: urlString) else { return }
        uiView.load(URLRequest(url: url))
    }
}



struct SchoolCalendarEmptyState: View
{
    @AppStorage("enableLiquidGlassEffect") private var enableLiquidGlassEffect: Bool = false

    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View
    {
        VStack(spacing: 8)
        {
            Image(systemName: systemImage)
                .font(.system(size: 34))
                .foregroundColor(.secondary.opacity(0.5))
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .appTextOpacity()
            Text(subtitle)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary.opacity(0.65))
                .appTextOpacity()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
        .optionalLiquidGlass(
            enabled: enableLiquidGlassEffect,
            cornerRadius: 18,
            fallback: Color(.secondarySystemBackground).opacity(0.55)
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - 校历事件行

struct SchoolEventRow: View
{
    @AppStorage("enableLiquidGlassEffect") private var enableLiquidGlassEffect: Bool = false

    let event: SchoolCalendarEvent

    var body: some View
    {
        HStack(spacing: 10)
        {
            ZStack
            {
                Circle()
                    .fill(event.type.typeColor.opacity(0.15))
                    .componentBackgroundOpacity()
                    .frame(width: 32, height: 32)
                Image(systemName: event.type.systemImage)
                    .font(.system(size: 14))
                    .foregroundColor(event.type.typeColor)
            }

            VStack(alignment: .leading, spacing: 2)
            {
                Text(event.title)
                    .font(.system(size: 14, weight: .medium))
                    .appTextOpacity()

                HStack(spacing: 6)
                {
                    Text(event.formattedDateRange())
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .appTextOpacity()

                    Text(event.type.rawValue)
                        .font(.system(size: 10))
                        .appTextOpacity()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background { event.type.typeColor.opacity(0.1).componentBackgroundOpacity() }
                        .foregroundColor(event.type.typeColor)
                        .cornerRadius(3)
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .optionalLiquidGlass(
            enabled: enableLiquidGlassEffect,
            cornerRadius: 16,
            fallback: Color(.secondarySystemBackground).opacity(0.72)
        )
    }
}

// MARK: - 校历事件颜色

extension SchoolEventType
{
    var typeColor: Color
    {
        switch self
        {
        case .holiday: return .orange
        case .exam: return .red
        case .trimesterStart: return .green
        case .trimesterEnd: return .blue
        case .activity: return .purple
        case .other: return .gray
        }
    }
}

#if DEBUG
#Preview("校历")
{
    NavigationStack
    {
        SchoolCalendarView()
            .environmentObject(userInfo())
    }
}
#endif
