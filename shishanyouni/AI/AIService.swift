//
//  AIService.swift
//  shishanyouni
//
//  AI 智学助手（beta）核心网络层。
//  参考 Zhitu 的 AIService 实现：支持 OpenAI 兼容协议（DeepSeek/Qwen/GPT/Kimi）与 Anthropic 协议（Claude）。
//

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

// MARK: - 服务

enum AIService
{
    static let availableModels: [AIModelConfig] = [
        AIModelConfig(id: "deepseek-chat", displayName: "DeepSeek Chat", apiEndpoint: "https://api.deepseek.com/v1/chat/completions", description: "DeepSeek 经典版 · 稳定便宜"),
        AIModelConfig(id: "deepseek-reasoner", displayName: "DeepSeek Reasoner", apiEndpoint: "https://api.deepseek.com/v1/chat/completions", description: "深度思考 · 适合复杂分析"),
        AIModelConfig(id: "qwen-turbo", displayName: "通义千问 Qwen Turbo", apiEndpoint: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions", description: "阿里系 · 国内稳定"),
        AIModelConfig(id: "glm-4-flash", displayName: "智谱 GLM-4-Flash", apiEndpoint: "https://open.bigmodel.cn/api/paas/v4/chat/completions", description: "免费额度 · 性价比高"),
        AIModelConfig(id: "gpt-4o-mini", displayName: "GPT-4o mini", apiEndpoint: "https://api.openai.com/v1/chat/completions", description: "国际主流 · 轻量"),
        AIModelConfig(id: "claude-3-5-sonnet-20241022", displayName: "Claude 3.5 Sonnet", apiEndpoint: "https://api.anthropic.com/v1/messages", description: "长上下文优势", isAnthropic: true),
    ]

    static func modelConfig(for id: String) -> AIModelConfig?
    {
        availableModels.first { $0.id == id }
    }

    enum StreamResult
    {
        case success(AsyncStream<String>)
        case failure(Int, String)
    }

    static func sendMessageWithStatus(
        modelId: String,
        apiKey: String,
        messages: [ChatAPIMessage],
        systemPrompt: String? = nil
    ) async throws -> StreamResult
    {
        guard let config = modelConfig(for: modelId) else
        {
            throw AIError.invalidModel
        }

        var request = URLRequest(url: URL(string: config.apiEndpoint)!)
        request.httpMethod = "POST"
        request.timeoutInterval = 60

        if config.isAnthropic
        {
            let body = buildAnthropicBody(modelId: modelId, messages: messages, systemPrompt: systemPrompt, stream: true)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        else
        {
            let body = buildOpenAIBody(modelId: modelId, messages: messages, systemPrompt: systemPrompt, stream: true)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let session = URLSession(configuration: .ephemeral)
        let (bytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else
        {
            throw AIError.networkError("无效的服务器响应")
        }

        guard httpResponse.statusCode == 200 else
        {
            var detail = ""
            for try await line in bytes.lines.prefix(5) { detail += line }
            return .failure(httpResponse.statusCode, detail)
        }

        let stream = AsyncStream<String>
        { continuation in
            Task
            {
                do
                {
                    for try await line in bytes.lines
                    {
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonStr = String(line.dropFirst(6))
                        if jsonStr == "[DONE]"
                        {
                            continuation.finish()
                            return
                        }
                        guard let data = jsonStr.data(using: .utf8) else { continue }
                        if config.isAnthropic
                        {
                            if let event = try? JSONDecoder().decode(AnthropicStreamEvent.self, from: data),
                               let text = event.delta?.text
                            {
                                continuation.yield(text)
                            }
                        }
                        else
                        {
                            guard let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data),
                                  let delta = chunk.choices?.first?.delta else { continue }
                            if let reasoning = delta.reasoningContent
                            {
                                continuation.yield("[思考] \(reasoning)")
                            }
                            if let content = delta.content
                            {
                                continuation.yield(content)
                            }
                        }
                    }
                    continuation.finish()
                }
                catch
                {
                    continuation.finish()
                }
            }
        }
        return .success(stream)
    }

    static func sendMessageSync(
        modelId: String,
        apiKey: String,
        messages: [ChatAPIMessage],
        systemPrompt: String? = nil
    ) async throws -> String
    {
        guard let config = modelConfig(for: modelId) else
        {
            throw AIError.invalidModel
        }

        var request = URLRequest(url: URL(string: config.apiEndpoint)!)
        request.httpMethod = "POST"
        request.timeoutInterval = 60

        if config.isAnthropic
        {
            let body = buildAnthropicBody(modelId: modelId, messages: messages, systemPrompt: systemPrompt, stream: false)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        else
        {
            let body = buildOpenAIBody(modelId: modelId, messages: messages, systemPrompt: systemPrompt, stream: false)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let session = URLSession(configuration: .ephemeral)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else
        {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw AIError.networkError("HTTP \(status)")
        }

        if config.isAnthropic
        {
            let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
            return decoded.content?.compactMap { $0.text }.joined() ?? ""
        }
        else
        {
            let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
            return decoded.choices?.first?.message?.content ?? ""
        }
    }

    // MARK: - 请求体构建

    private static func buildOpenAIBody(modelId: String, messages: [ChatAPIMessage], systemPrompt: String?, stream: Bool) -> [String: Any]
    {
        var apiMessages: [[String: String]] = []
        if let system = systemPrompt, !system.isEmpty
        {
            apiMessages.append(["role": "system", "content": system])
        }
        for msg in messages
        {
            let role = msg.role == "agent" ? "assistant" : msg.role
            apiMessages.append(["role": role, "content": msg.content])
        }
        if apiMessages.isEmpty
        {
            apiMessages.append(["role": "user", "content": "你好"])
        }
        return [
            "model": modelId,
            "messages": apiMessages,
            "stream": stream,
            "temperature": 0.7,
            "max_tokens": 4096
        ]
    }

    private static func buildAnthropicBody(modelId: String, messages: [ChatAPIMessage], systemPrompt: String?, stream: Bool) -> [String: Any]
    {
        var apiMessages: [[String: Any]] = []
        for msg in messages
        {
            let role = msg.role == "agent" ? "assistant" : (msg.role == "system" ? "user" : msg.role)
            apiMessages.append(["role": role, "content": msg.content])
        }
        if apiMessages.isEmpty
        {
            apiMessages.append(["role": "user", "content": "你好"])
        }
        var body: [String: Any] = [
            "model": modelId,
            "max_tokens": 4096,
            "messages": apiMessages
        ]
        if let system = systemPrompt, !system.isEmpty
        {
            body["system"] = system
        }
        if stream
        {
            body["stream"] = true
        }
        return body
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

private struct StreamChunk: Codable
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

private struct ChatResponse: Codable
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

private struct AnthropicStreamEvent: Codable
{
    let type: String?
    let delta: Delta?

    struct Delta: Codable
    {
        let type: String?
        let text: String?
    }
}

private struct AnthropicResponse: Codable
{
    let content: [Content]?

    struct Content: Codable
    {
        let type: String?
        let text: String?
    }
}
