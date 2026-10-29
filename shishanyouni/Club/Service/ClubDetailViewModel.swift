import SwiftUI

// MARK: - ViewModel

@MainActor
class ClubDetailViewModel: ObservableObject
{
    @Published var detail: ClubDetail?
    @Published var isLoading = true
    @Published var errorMessage: String?

    func fetch(id: Int) async
    {
        do
        {
            detail = try await ClubAPI.fetchDetail(id: id)
        }
        catch
        {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
        isLoading = false
    }
}
