import Foundation

// 学校统一身份认证的绑定结果。


enum CASBindResult {
    case success
    case failure(message: String)
}
