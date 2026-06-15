import AppKit
import SwiftUI

/// AppKit-backed secure text entry for the notch panel.
/// Avoids SwiftUI `SecureField`, which routes through ViewBridge / RemoteViewService
/// and logs benign-but-noisy disconnect warnings in borderless NSPanels.
struct SecureTokenField: View {
    let placeholder: String
    @Binding var text: String
    var isFocused: Binding<Bool>?
    var onSubmit: (() -> Void)?

    var body: some View {
        SecureTokenFieldRepresentable(
            placeholder: placeholder,
            text: $text,
            isFocused: isFocused,
            onSubmit: onSubmit
        )
    }
}

private struct SecureTokenFieldRepresentable: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var isFocused: Binding<Bool>?
    var onSubmit: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: isFocused, onSubmit: onSubmit)
    }

    func makeNSView(context: Context) -> NSSecureTextField {
        let field = NSSecureTextField(frame: .zero)
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 15)
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.submit)
        field.placeholderString = placeholder
        field.stringValue = text
        context.coordinator.field = field
        return field
    }

    func updateNSView(_ field: NSSecureTextField, context: Context) {
        context.coordinator.onSubmit = onSubmit

        if field.stringValue != text {
            field.stringValue = text
        }

        if let isFocused {
            if isFocused.wrappedValue, field.window?.firstResponder !== field.currentEditor() {
                field.window?.makeFirstResponder(field)
            } else if !isFocused.wrappedValue, field.window?.firstResponder === field.currentEditor() {
                field.window?.makeFirstResponder(nil)
            }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String
        var isFocused: Binding<Bool>?
        var onSubmit: (() -> Void)?
        weak var field: NSSecureTextField?

        init(
            text: Binding<String>,
            isFocused: Binding<Bool>?,
            onSubmit: (() -> Void)?
        ) {
            _text = text
            self.isFocused = isFocused
            self.onSubmit = onSubmit
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            text = field.stringValue
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            isFocused?.wrappedValue = true
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            isFocused?.wrappedValue = false
        }

        @objc func submit() {
            onSubmit?()
        }
    }
}
