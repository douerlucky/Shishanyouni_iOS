import SwiftUI

/// 只管理一次验证码呈现。等 Sheet 完成收起后才恢复请求，避免重试时重叠呈现。
@MainActor
final class ShishanyouniMFAPresenter: ObservableObject
{
    @Published var challenge: ShishanyouniV3Challenge?
    @Published var code = ""
    private(set) var initialCountdown = 0
    private var continuation: CheckedContinuation<String?, Never>?
    private var pendingCode: String?

    var provider: ShishanyouniV3MFAProvider
    {
        { [self] challenge in await request(challenge) }
    }

    func request(_ challenge: ShishanyouniV3Challenge) async -> String?
    {
        guard !Task.isCancelled, continuation == nil else { return nil }
        initialCountdown = await ShishanyouniV3Session.shared.remainingSMSCooldown(sessionId: challenge.sessionId)
        code = ""
        pendingCode = nil
        return await withTaskCancellationHandler
        {
            await withCheckedContinuation
            { continuation in
                self.continuation = continuation
                self.challenge = challenge
            }
        }
        onCancel: { Task { @MainActor in self.cancel() } }
    }

    func dismiss(with code: String?)
    {
        pendingCode = code
        challenge = nil
    }

    func didDismiss()
    {
        let continuation = self.continuation
        self.continuation = nil
        continuation?.resume(returning: pendingCode)
        pendingCode = nil
    }

    func cancel()
    {
        pendingCode = nil
        challenge = nil
        didDismiss()
    }
}

extension ShishanyouniV3Challenge: Identifiable
{
    var id: String { sessionId }
}
