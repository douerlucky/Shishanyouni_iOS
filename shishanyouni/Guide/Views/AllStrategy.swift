import SwiftUI

// MARK: - 主视图

struct AllStrategy: View
{
    @StateObject private var viewModel = AllStrategyViewModel()

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

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
                        ProgressView()
                            .scaleEffect(1.4)
                        Text("加载中...")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                }
                else if let error = viewModel.errorMessage
                {
                    VStack(spacing: 16)
                    {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(error)
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("重新加载")
                        {
                            viewModel.fetchGuides()
                        }
                        .nativeGlassButtonStyle(prominent: true)
                    }
                }
                else if viewModel.guides.isEmpty
                {
                    VStack(spacing: 16)
                    {
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("暂无攻略")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                }
                else
                {
                    ScrollView
                    {
                        LazyVGrid(columns: columns, spacing: 12)
                        {
                            ForEach(viewModel.guides)
                            { guide in
                                NavigationLink(destination: StrategyDetailView(guideId: guide.id))
                                {
                                    GuideCard(guide: guide)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("校园攻略")
            .toolbar(.hidden, for: .tabBar)
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear
        {
            viewModel.fetchGuides()
        }
    }
}
