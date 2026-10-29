import Foundation

// MARK: - 对话消息

struct AIChatMessage: Identifiable
{
    let id = UUID()
    let role: String // "user" / "agent"
    let content: String
}
