import SwiftUI

/// The collapsed bar. Wider than the notch so info sits in the strips beside the
/// camera: work title + project dot on the left, running timer on the right.
struct CollapsedPill: View {
    @Environment(NotchStore.self) private var store
    @Environment(\.morphNamespace) private var morph

    private var isRunning: Bool { store.runningEntry != nil }
    private var isOnboarding: Bool { store.isOnboarding }

    var body: some View {
        HStack(spacing: 0) {
            leftStrip
                .frame(width: NotchMetrics.collapsedSideWidth, alignment: .leading)

            Color.clear
                .frame(width: store.notchSize.width)

            rightStrip
                .frame(width: NotchMetrics.collapsedSideWidth, alignment: .trailing)
        }
        .frame(
            width: NotchMetrics.collapsedShellWidth(notchWidth: store.notchSize.width),
            height: store.notchSize.height
        )
        .modifier(CollapsedOpenGesture())
    }

    private var leftStrip: some View {
        HStack(spacing: NotchMetrics.collapsedStripItemSpacing) {
            if isOnboarding {
                Circle()
                    .fill(NotchColors.textTertiary)
                    .frame(width: NotchMetrics.statusDotSize, height: NotchMetrics.statusDotSize)
                Text("Set up")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(NotchColors.textSecondary)
            } else {
                statusIndicator

                TruncatingLine(
                    text: store.collapsedWorkTitle,
                    font: .system(size: 12, weight: .medium),
                    color: isRunning ? NotchColors.textPrimary : NotchColors.textSecondary,
                    morphID: .title,
                    morphNamespace: morph,
                    morphIsSource: !store.isExpanded
                )
            }
        }
        .padding(.leading, NotchMetrics.collapsedStripLeadingPadding)
        .padding(.trailing, NotchMetrics.collapsedStripTrailingPadding)
    }

    private var rightStrip: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            if let running = store.runningEntry {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let elapsed = max(0, Int(context.date.timeIntervalSince(running.startedAt)))
                    Text(TimeFormatting.formatTimer(elapsed))
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(NotchColors.textSecondary)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .morphMatched(.timer, in: morph, properties: .position, anchor: .trailing, isSource: !store.isExpanded)
            }
        }
        .padding(.trailing, 16)
        .padding(.leading, 8)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if let project = store.runningProject {
            ProjectDot(color: project.color, size: NotchMetrics.statusDotSize)
        } else {
            ActiveDot(active: isRunning, offline: store.isOffline)
                .frame(width: NotchMetrics.statusDotSize, height: NotchMetrics.statusDotSize)
        }
    }
}

private struct CollapsedOpenGesture: ViewModifier {
    @Environment(NotchStore.self) private var store

    func body(content: Content) -> some View {
        if store.panelOpenTrigger == .click {
            content
                .contentShape(.rect)
                .onTapGesture { store.expand() }
                .pointerStyle(.link)
        } else {
            content
        }
    }
}

#Preview {
    CollapsedPill()
        .environment(NotchStore())
        .background(.black)
}
