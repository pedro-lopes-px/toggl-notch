import SwiftUI

struct OnboardingView: View {
    @Environment(NotchStore.self) private var store
    @State private var token = ""
    @State private var isConnecting = false
    @State private var hasError = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            Text("Toggl Notch")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(NotchColors.textPrimary)
            Text("Paste your Toggl API token")
                .font(.system(size: 13))
                .foregroundStyle(NotchColors.textSecondary)

            VStack(alignment: .leading, spacing: 4) {
                SecureField("API token", text: $token)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundStyle(NotchColors.textPrimary)
                    .focused($focused)
                    .onChange(of: token) { _, _ in hasError = false }
                Rectangle()
                    .fill(hasError ? NotchColors.accentRedDim : NotchColors.borderSubtle)
                    .frame(height: 1)
                if hasError {
                    Text("That token didn't work")
                        .font(.system(size: 11))
                        .foregroundStyle(NotchColors.accentRedDim.opacity(0.8))
                }
            }
            .frame(maxWidth: 260)

            Button(action: connect) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Connect")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(NotchColors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(NotchColors.surfaceRaised, in: .rect(cornerRadius: 10))
            }
            .buttonStyle(PressableButtonStyle())
            .pointerStyle(.link)
            .disabled(isConnecting || token.isEmpty)
            .opacity(isConnecting || token.isEmpty ? 0.4 : 1)

            Button("Find it in Toggl Profile settings") {
                if let url = URL(string: "https://track.toggl.com/profile") {
                    NSWorkspace.shared.open(url)
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(NotchColors.textTertiary)
            .buttonStyle(.plain)
            .pointerStyle(.link)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { focused = true }
    }

    private func connect() {
        isConnecting = true
        Task {
            do {
                try await store.connect(token: token.trimmingCharacters(in: .whitespacesAndNewlines))
            } catch {
                hasError = true
            }
            isConnecting = false
        }
    }
}
