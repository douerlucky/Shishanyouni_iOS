import SwiftUI

// MARK: - 分析结果通用容器

struct AnalysisResultView: View
{
    let dataCount: Int
    let dataName: String
    let missingHint: String
    let isLoading: Bool
    let result: String
    let actionTitle: String
    let action: () -> Void

    var body: some View
    {
        ScrollView
        {
            VStack(alignment: .leading, spacing: 16)
            {
                if dataCount > 0
                {
                    Text("已读取 \(dataCount) 条\(dataName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if result.isEmpty && !isLoading
                {
                    if dataCount == 0
                    {
                        VStack(spacing: 12)
                        {
                            Image(systemName: "tray")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary)
                            Text(missingHint)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                    else
                    {
                        Button(action: action)
                        {
                            Label(actionTitle, systemImage: "sparkles")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                        }
                        .nativeGlassButtonStyle(prominent: true, fillsWidth: true)
                        .tint(.blue)
                        .controlSize(.large)
                    }
                }
                else if isLoading
                {
                    VStack(spacing: 12)
                    {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("AI 正在分析...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)

                    if !result.isEmpty
                    {
                        resultText
                    }
                }
                else
                {
                    resultText

                    Button("重新分析")
                    {
                        action()
                    }
                    .font(.subheadline)
                    .nativeGlassButtonStyle()
                }
            }
            .padding()
        }
    }

    private var resultText: some View
    {
        Text(result)
            .font(.system(size: 15))
            .lineSpacing(5)
            .textSelection(.enabled)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
    }
}

// MARK: - 对话视图

struct AIChatView: View
{
    @ObservedObject var vm: AIAssistantViewModel
    let username: String

    @State private var input = ""
    @FocusState private var inputFocused: Bool

    var body: some View
    {
        VStack(spacing: 0)
        {
            ScrollViewReader
            { proxy in
                ScrollView
                {
                    VStack(alignment: .leading, spacing: 12)
                    {
                        if vm.chatMessages.isEmpty
                        {
                            VStack(spacing: 10)
                            {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 36))
                                    .foregroundColor(.blue)
                                Text("可以问我：\n• 我的绩点怎么样？怎么提升？\n• 这几门课怎么安排学习？\n• 帮我制定期末复习计划")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 50)
                        }
                        else
                        {
                            ForEach(vm.chatMessages)
                            { message in
                                AIChatBubble(message: message)
                            }
                        }

                        if vm.isChatLoading
                        {
                            HStack(spacing: 6)
                            {
                                ProgressView()
                                Text("思考中...")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 12)
                        }
                    }
                    .padding()
                }
                .onChange(of: vm.chatMessages.count)
                { _ in
                    if let last = vm.chatMessages.last
                    {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            inputBar
        }
    }

    private var inputBar: some View
    {
        HStack(spacing: 10)
        {
            TextField("输入你的问题...", text: $input, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
                .focused($inputFocused)

            Button
            {
                let text = input
                input = ""
                Task { await vm.sendChat(text, username: username) }
            } label:
            {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(vm.isChatLoading ? .gray : .blue)
            }
            .disabled(vm.isChatLoading)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(uiColor: .systemBackground))
    }
}

private struct AIChatBubble: View
{
    let message: AIChatMessage

    var isUser: Bool { message.role == "user" }

    var body: some View
    {
        HStack
        {
            if isUser { Spacer(minLength: 40) }

            Text(message.content)
                .font(.system(size: 15))
                .lineSpacing(4)
                .textSelection(.enabled)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isUser ? Color.blue : Color(uiColor: .secondarySystemGroupedBackground))
                )
                .foregroundColor(isUser ? .white : .primary)

            if !isUser { Spacer(minLength: 40) }
        }
    }
}

#Preview
{
    NavigationStack
    {
        AIAssistantView()
            .environmentObject(userInfo())
    }
}
