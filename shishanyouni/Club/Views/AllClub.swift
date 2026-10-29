import SwiftUI

// MARK: - Main View

struct AllClub: View
{
    @StateObject private var viewModel = AllClubViewModel()
    @State private var searchText = ""

    var displayGroups: [(letter: String, clubs: [Club])]
    {
        viewModel.filtered(by: searchText)
    }

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
                        ProgressView().scaleEffect(1.4)
                        Text("加载社团列表…")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                else if let err = viewModel.errorMessage
                {
                    VStack(spacing: 16)
                    {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary)
                        Text(err)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        Button("重试") { Task { await viewModel.fetchClubs() } }
                            .nativeGlassButtonStyle(prominent: true)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                else
                {
                    ClubIndexList(groups: displayGroups, searchText: searchText)
                        .searchable(
                            text: $searchText,
                            placement: .navigationBarDrawer(displayMode: .always),
                            prompt: "搜索社团名称"
                        )
                }
            }
            .navigationTitle("全部社团")
            .navigationBarTitleDisplayMode(.large)
            .toolbar(.hidden, for: .tabBar)
        }
        .navigationViewStyle(.stack)
        .task { await viewModel.fetchClubs() }
    }
}
