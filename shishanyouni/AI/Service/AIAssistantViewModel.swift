import SwiftUI

// MARK: - ViewModel

@MainActor
class AIAssistantViewModel: ObservableObject
{
    @Published var gpaResult = ""
    @Published var courseResult = ""
    @Published var isGPALoading = false
    @Published var isCourseLoading = false

    @Published var chatMessages: [AIChatMessage] = []
    @Published var isChatLoading = false

    @Published var gpaDataCount = 0
    @Published var courseDataCount = 0

    private var chatTask: Task<Void, Never>?

    var hasAPIKey: Bool { AIKeyStore.hasAPIKey }

    func refreshData(username: String)
    {
        gpaDataCount = AIAnalysis.collectGradeData(username: username).count
        courseDataCount = AIAnalysis.collectCourseData().count
    }

    // MARK: - 绩点分析

    func analyzeGPA(username: String) async
    {
        let semesters = AIAnalysis.collectGradeData(username: username)
        gpaDataCount = semesters.count
        guard !semesters.isEmpty else
        {
            gpaResult = ""
            return
        }

        isGPALoading = true
        gpaResult = ""

        do
        {
            let stream = try await AIAPI.sendMessageWithStatus(
                modelId: AIKeyStore.selectedModelID,
                apiKey: AIKeyStore.apiKey,
                messages: [ChatAPIMessage(role: "user", content: AIAnalysis.buildGPAAnalysisPrompt(semesters: semesters, username: username))],
                systemPrompt: "你是一名专业的大学学业规划助手，回答用中文。"
            )

            switch stream
            {
            case .success(let stream):
                for await chunk in stream
                {
                    gpaResult += chunk
                }
            case .failure(let code, let body):
                gpaResult = "请求失败（HTTP \(code)）：\(String(body.prefix(300)))"
            }
        }
        catch
        {
            gpaResult = error.localizedDescription
        }

        isGPALoading = false
    }

    // MARK: - 课程分析

    func analyzeCourses(username: String) async
    {
        let courses = AIAnalysis.collectCourseData()
        let semesters = AIAnalysis.collectGradeData(username: username)
        courseDataCount = courses.count
        guard !courses.isEmpty || !semesters.isEmpty else
        {
            courseResult = ""
            return
        }

        isCourseLoading = true
        courseResult = ""

        do
        {
            let stream = try await AIAPI.sendMessageWithStatus(
                modelId: AIKeyStore.selectedModelID,
                apiKey: AIKeyStore.apiKey,
                messages: [ChatAPIMessage(role: "user", content: AIAnalysis.buildCourseAnalysisPrompt(courses: courses, semesters: semesters, username: username))],
                systemPrompt: "你是一名专业的大学课程学习规划助手，回答用中文。"
            )

            switch stream
            {
            case .success(let stream):
                for await chunk in stream
                {
                    courseResult += chunk
                }
            case .failure(let code, let body):
                courseResult = "请求失败（HTTP \(code)）：\(String(body.prefix(300)))"
            }
        }
        catch
        {
            courseResult = error.localizedDescription
        }

        isCourseLoading = false
    }

    // MARK: - 自由对话

    func sendChat(_ text: String, username: String) async
    {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isChatLoading else { return }

        chatMessages.append(AIChatMessage(role: "user", content: trimmed))
        isChatLoading = true

        var history: [ChatAPIMessage] = chatMessages.map { ChatAPIMessage(role: $0.role == "agent" ? "assistant" : "user", content: $0.content) }
        history = Array(history.suffix(20))
        let systemPrompt = AIAnalysis.buildChatSystemPrompt(semesters: AIAnalysis.collectGradeData(username: username))

        chatTask = Task
        {
            do
            {
                let stream = try await AIAPI.sendMessageWithStatus(
                    modelId: AIKeyStore.selectedModelID,
                    apiKey: AIKeyStore.apiKey,
                    messages: history,
                    systemPrompt: systemPrompt
                )

                switch stream
                {
                case .success(let stream):
                    var buffer = ""
                    for await chunk in stream
                    {
                        buffer += chunk
                        updateLastAgentMessage(buffer)
                    }
                case .failure(let code, let body):
                    updateLastAgentMessage("请求失败（HTTP \(code)）：\(String(body.prefix(300)))")
                }
            }
            catch
            {
                updateLastAgentMessage(error.localizedDescription)
            }
            isChatLoading = false
        }
    }

    private func updateLastAgentMessage(_ content: String)
    {
        if let last = chatMessages.last, last.role == "agent"
        {
            chatMessages[chatMessages.count - 1] = AIChatMessage(role: "agent", content: content)
        }
        else
        {
            chatMessages.append(AIChatMessage(role: "agent", content: content))
        }
    }

    func cancelChat()
    {
        chatTask?.cancel()
        isChatLoading = false
    }
}
