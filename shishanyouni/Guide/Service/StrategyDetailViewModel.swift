import SwiftUI

// MARK: - ViewModel

class StrategyDetailViewModel: ObservableObject
{
    @Published var guide: GuideDetail? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    func fetchDetail(id: Int)
    {
        isLoading = true
        errorMessage = nil

        GuideAPI.fetchDetail(id: id)
        { result in
            DispatchQueue.main.async
            {
                self.isLoading = false
                switch result
                {
                case let .success(guide):
                    self.guide = guide
                    if self.guide == nil { self.errorMessage = "未找到该攻略" }
                case let .failure(.request(error)):
                    self.errorMessage = "请求失败：\(error.localizedDescription)"
                case .failure(.missingData):
                    self.errorMessage = "无数据返回"
                case let .failure(.decoding(error)):
                    self.errorMessage = "解析失败：\(error.localizedDescription)"
                }
            }
        }
    }
}
