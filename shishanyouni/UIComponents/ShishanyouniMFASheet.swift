import SwiftUI

private struct ShishanyouniMFASheetModifier: ViewModifier
{
    @ObservedObject var presenter: ShishanyouniMFAPresenter

    func body(content: Content) -> some View
    {
        content
            .sheet(item: $presenter.challenge, onDismiss: presenter.didDismiss)
            { challenge in
                MFACodeInputSheet(
                    maskedPhone: challenge.phone ?? "",
                    code: $presenter.code,
                    fromShishanyouni: true,
                    validationMessage: challenge.validationMessage,
                    initialCountdown: presenter.initialCountdown,
                    onSendCode: .constant({
                        do
                        {
                            try await ShishanyouniV3Session.shared.sendCode(sessionId: challenge.sessionId)
                            return nil
                        }
                        catch { return error.localizedDescription }
                    }),
                    onCancel: { presenter.dismiss(with: nil) },
                    onConfirm: { presenter.dismiss(with: presenter.code.trimmingCharacters(in: .whitespacesAndNewlines)) }
                )
            }
            .onDisappear { presenter.cancel() }
    }
}

extension View
{
    func shishanyouniMFA(_ presenter: ShishanyouniMFAPresenter) -> some View
    {
        modifier(ShishanyouniMFASheetModifier(presenter: presenter))
    }
}
