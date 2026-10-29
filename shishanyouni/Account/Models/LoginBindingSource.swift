import Foundation

enum LoginBindingSource: String, QuerySourceOption
{
    case shishanyouni
    case cas

    var id: String { rawValue }

    var title: String
    {
        switch self
        {
        case .shishanyouni:
            return "狮山有你服务器"
        case .cas:
            return SchoolServiceName.unifiedIdentity
        }
    }
}
