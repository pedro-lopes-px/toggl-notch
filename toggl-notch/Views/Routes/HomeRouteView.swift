import SwiftUI

struct HomeRouteView: View {
    @Environment(NotchStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var expanded: Bool { store.isExpanded }

    var body: some View {
        VStack(alignment: .leading, spacing: NotchMetrics.sectionGap) {
            PanelHeader()
                .padding(.top, 8)

            RevealedPanelSection(index: 1, expanded: expanded, reduceMotion: reduceMotion) {
                divider
                if store.isLoadingHome {
                    VStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { _ in SkeletonRow() }
                    }
                } else {
                    TodaySummary()
                }
            }

            RevealedPanelSection(index: 2, expanded: expanded, reduceMotion: reduceMotion) {
                divider
            }

            RevealedPanelSection(index: 3, expanded: expanded, reduceMotion: reduceMotion) {
                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel("Recent")
                    RecentEntries()
                }
            }
        }
        .padding(NotchMetrics.panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var divider: some View {
        Rectangle()
            .fill(NotchColors.borderSubtle)
            .frame(height: 1)
    }
}

private struct RevealedPanelSection<Content: View>: View {
    let index: Int
    let expanded: Bool
    let reduceMotion: Bool
    @ViewBuilder let content: Content

    var body: some View {
        content
            .opacity(expanded ? 1 : 0)
            .offset(y: expanded ? 0 : 6)
            .animation(
                NotchMetrics.sectionRevealAnimation(index: index, expanded: expanded, reduceMotion: reduceMotion),
                value: expanded
            )
    }
}
