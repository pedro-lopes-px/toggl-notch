import SwiftUI

/// Shown when Toggl returns HTTP 402 (hourly quota). Counts down using `X-Toggl-Quota-Resets-In`.
struct QuotaLimitBanner: View {
    let resetsAt: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, Int(resetsAt.timeIntervalSince(context.date).rounded(.down)))

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "hourglass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(NotchColors.textSecondary)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Hourly API limit reached")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(NotchColors.textPrimary)
                    Text(remaining > 0
                        ? "Your token is fine. Resets in \(TimeFormatting.formatTimer(remaining))."
                        : "Retrying now…")
                        .font(.system(size: 11))
                        .foregroundStyle(NotchColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(NotchColors.surfaceRaised, in: .rect(cornerRadius: 10))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hourly API limit reached")
    }
}

#Preview {
    QuotaLimitBanner(resetsAt: .now.addingTimeInterval(42 * 60 + 18))
        .padding()
        .background(NotchColors.surfaceNotch)
}
