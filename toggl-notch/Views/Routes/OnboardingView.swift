import SwiftUI

struct OnboardingView: View {
    @Environment(NotchStore.self) private var store
    @State private var token = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?
    @State private var isFieldFocused = false

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
                SecureTokenField(
                    placeholder: "API token",
                    text: $token,
                    isFocused: $isFieldFocused
                )
                .font(.system(size: 15))
                .foregroundStyle(NotchColors.textPrimary)
                .onChange(of: token) { _, _ in errorMessage = nil }
                Rectangle()
                    .fill(errorMessage == nil ? NotchColors.borderSubtle : NotchColors.accentRedDim)
                    .frame(height: 1)
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(NotchColors.accentRedDim.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
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
        .onAppear { isFieldFocused = true }
    }

    private func connect() {
        isConnecting = true
        Task {
            defer { isConnecting = false }
            do {
                try await store.connect(token: token)
            } catch TogglAPIError.quotaExceeded {
                errorMessage = nil
            } catch let error as TogglAPIError {
                errorMessage = error.userMessage
            } catch {
                errorMessage = "Something went wrong. Try again."
            }
        }
    }
}

/// Shown when a saved token exists but the account couldn't be loaded (e.g. after a rebuild or offline launch).
struct SessionRecoveryView: View {
    @Environment(NotchStore.self) private var store
    @State private var isRetrying = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            Text("Couldn't load your account")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(NotchColors.textPrimary)
            Text("Your token is saved. Check your connection and try again.")
                .font(.system(size: 13))
                .foregroundStyle(NotchColors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(NotchColors.accentRedDim.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
            }

            Button(action: retry) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Retry")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(NotchColors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(NotchColors.surfaceRaised, in: .rect(cornerRadius: 10))
            }
            .buttonStyle(PressableButtonStyle())
            .pointerStyle(.link)
            .disabled(isRetrying)
            .opacity(isRetrying ? 0.4 : 1)
            .frame(maxWidth: 260)

            Button("Use a different token") {
                store.disconnect()
            }
            .font(.system(size: 11))
            .foregroundStyle(NotchColors.textTertiary)
            .buttonStyle(.plain)
            .pointerStyle(.link)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func retry() {
        isRetrying = true
        errorMessage = nil
        Task {
            defer { isRetrying = false }
            let ok = await store.bootstrap()
            if !ok {
                if store.isQuotaLimited {
                    errorMessage = nil
                } else {
                    errorMessage = store.isOffline
                        ? "No internet connection."
                        : "Still couldn't connect. Try again or use a different token."
                }
            }
        }
    }
}
