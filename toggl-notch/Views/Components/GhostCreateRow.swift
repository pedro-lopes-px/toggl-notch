import SwiftUI

struct GhostCreateRow: View {
    let title: String
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    @State private var editing = false
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if editing {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                        .foregroundStyle(NotchColors.textSecondary)
                    TextField("Name", text: $text)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(NotchColors.textPrimary)
                        .focused($focused)
                        .onSubmit(submit)
                }
                .frame(height: NotchMetrics.rowHeight)
                .padding(.horizontal, 8)
                .onAppear { focused = true }
                .onExitCommand(perform: cancel)
            } else {
                Button(action: beginEdit) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 12))
                            .foregroundStyle(NotchColors.textSecondary)
                        Text(title)
                            .font(.system(size: 13))
                            .foregroundStyle(NotchColors.textSecondary)
                        Spacer(minLength: 0)
                    }
                    .frame(height: NotchMetrics.rowHeight)
                    .padding(.horizontal, 8)
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
            }
        }
        .animation(.easeOut(duration: 0.15), value: editing)
    }

    private func beginEdit() {
        withAnimation { editing = true }
    }

    private func submit() {
        let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { cancel(); return }
        onSubmit(name)
        text = ""
        editing = false
    }

    private func cancel() {
        text = ""
        editing = false
        onCancel()
    }
}
