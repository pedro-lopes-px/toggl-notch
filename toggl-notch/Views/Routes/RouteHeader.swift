import SwiftUI

struct RouteHeader: View {
    let title: String
    var trailingAction: (() -> Void)?
    var trailingSymbol: String = "plus"
    var trailingLabel: String = "Create"

    @Environment(NotchStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                CircularIconButton(
                    systemName: "chevron.left",
                    label: "Back",
                    hoverTint: NotchColors.textPrimary,
                    iconSize: 12,
                    action: { store.pop() }
                )

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NotchColors.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if let trailingAction {
                    CircularIconButton(
                        systemName: trailingSymbol,
                        label: trailingLabel,
                        hoverTint: NotchColors.textPrimary,
                        iconSize: 12,
                        action: trailingAction
                    )
                }

                miniTimer
            }
            .frame(height: 40)
            .padding(.horizontal, NotchMetrics.panelPadding)

            Rectangle()
                .fill(NotchColors.borderSubtle)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private var miniTimer: some View {
        if let running = store.runningEntry {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let elapsed = max(0, Int(context.date.timeIntervalSince(running.startedAt)))
                Button {
                    store.popToHome()
                } label: {
                    Text(TimeFormatting.formatTimer(elapsed))
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(NotchColors.textSecondary)
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
            }
        }
    }
}
