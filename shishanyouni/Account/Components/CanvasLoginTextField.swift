import SwiftUI
import UIKit

struct CanvasLoginTextField: UIViewRepresentable
{
    @Binding var text: String
    let placeholder: String
    let isSecure: Bool
    let keyboardType: UIKeyboardType

    func makeUIView(context: Context) -> UITextField
    {
        let textField = PreviewTextField()
        textField.placeholder = placeholder
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.keyboardType = keyboardType
        textField.isSecureTextEntry = isSecure
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.textContentType = isSecure ? .password : .username
        textField.delegate = context.coordinator
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textDidChange(_:)),
            for: .editingChanged
        )
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context)
    {
        if uiView.text != text
        {
            uiView.text = text
        }
        uiView.placeholder = placeholder
        uiView.keyboardType = keyboardType
        uiView.isSecureTextEntry = isSecure
        (uiView as? PreviewTextField)?._intrinsicContentSize.height = uiView.bounds.height > 0 ? uiView.bounds.height : 44
        uiView.invalidateIntrinsicContentSize()
    }

    func makeCoordinator() -> Coordinator
    {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, UITextFieldDelegate
    {
        private var text: Binding<String>

        init(text: Binding<String>)
        {
            self.text = text
        }

        @objc func textDidChange(_ sender: UITextField)
        {
            text.wrappedValue = sender.text ?? ""
        }
    }
}
