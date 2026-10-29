// 两种认证方式共用的验证码输入协调，不负责网络请求。

import Foundation

typealias MFACodeProvider = @MainActor (_ maskedPhone: String?) async -> String?

enum MFACodeContext
{
    @TaskLocal static var sendCodeAction: (() async -> String?)?

    @MainActor private static var currentSendCodeAction: (() async -> String?)?

    @MainActor static var activeSendCodeAction: (() async -> String?)?
    {
        sendCodeAction ?? currentSendCodeAction
    }

    static func requestCode(
        using provider: MFACodeProvider,
        maskedPhone: String?,
        sendCodeAction: (() async -> String?)?
    ) async -> String?
    {
        await MainActor.run
        {
            currentSendCodeAction = sendCodeAction
        }

        let code = await $sendCodeAction.withValue(sendCodeAction)
        {
            await provider(maskedPhone)
        }

        await MainActor.run
        {
            currentSendCodeAction = nil
        }

        return code
    }
}
