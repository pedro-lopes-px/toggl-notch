import SwiftUI

struct ErrorToastView: View {
    let toast: ErrorToast
    let onDismiss: () -> Void
    let onRetry: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 11))
                .foregroundStyle(NotchColors.textTertiary)
            Text(toast.message)
                .font(.system(size: 12))
                .foregroundStyle(NotchColors.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            if let onRetry {
                Button("Retry", action: onRetry)
                    .font(.system(size: 12))
                    .foregroundStyle(NotchColors.textPrimary)
                    .buttonStyle(.plain)
                    .pointerStyle(.link)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(NotchColors.surfaceRaised, in: .rect(cornerRadius: 10))
        .padding(.horizontal, 12)
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
    }
}
