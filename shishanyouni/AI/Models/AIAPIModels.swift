import Foundation

// MARK: - 模型配置

struct AIModelConfig
{
    let id: String
    let displayName: String
    let apiEndpoint: String
    let description: String
    let isAnthropic: Bool

    init(id: String, displayName: String, apiEndpoint: String, description: String, isAnthropic: Bool = false)
    {
        self.id = id
        self.displayName = displayName
        self.apiEndpoint = apiEndpoint
        self.description = description
        self.isAnthropic = isAnthropic
    }
}

// MARK: - 消息与错误

struct ChatAPIMessage
{
    let role: String
    let content: String
}

enum AIError: LocalizedError
{
    case invalidModel
    case noAPIKey
    case networkError(String)

    var errorDescription: String?
    {
        switch self
        {
        case .invalidModel: return "无效的模型配置"
        case .noAPIKey: return "请先配置 API Key"
        case .networkError(let msg): return "网络错误：\(msg)"
        }
    }
}

// MARK: - 响应解析

struct StreamChunk: Codable
{
    let choices: [Choice]?

    struct Choice: Codable
    {
        let delta: Delta?

        struct Delta: Codable
        {
            let content: String?
            let reasoningContent: String?

            enum CodingKeys: String, CodingKey
            {
                case content
                case reasoningContent = "reasoning_content"
            }
        }
    }
}

struct ChatResponse: Codable
{
    let choices: [Choice]?

    struct Choice: Codable
    {
        let message: Message?

        struct Message: Codable
        {
            let content: String
        }
    }
}

struct AnthropicStreamEvent: Codable
{
    let type: String?
    let delta: Delta?

    struct Delta: Codable
    {
        let type: String?
        let text: String?
    }
}

struct AnthropicResponse: Codable
{
    let content: [Content]?

    struct Content: Codable
    {
        let type: String?
        let text: String?
    }
}
