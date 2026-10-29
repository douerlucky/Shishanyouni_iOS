import SwiftUI

// MARK: - ViewModel

class AllStrategyViewModel: ObservableObject
{
    @Published var guides: [Guide] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    func fetchGuides()
    {
        isLoading = true
        errorMessage = nil

        GuideAPI.fetchGuides
        { result in
            DispatchQueue.main.async
            {
                self.isLoading = false

                switch result
                {
                case let .success(guides):
                    self.guides = guides
                case let .failure(.request(error)):
                    self.errorMessage = "请求失败：\(error.localizedDescription)"
                case .failure(.missingData):
                    self.errorMessage = "无数据返回"
                case let .failure(.decoding(error)):
                    self.errorMessage = "数据解析失败：\(error.localizedDescription)"
                }
            }
        }
    }
}
