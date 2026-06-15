import SwiftUI

/// Route content with transitions and pinned NavBar.
struct PanelContent: View {
    @Environment(NotchStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                routeContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.bottom, 41) // NavBar height + divider
            }

            VStack(spacing: 0) {
                if let toast = store.errorToast {
                    ErrorToastView(
                        toast: toast,
                        onDismiss: { store.dismissError() },
                        onRetry: toast.retryAction
                    )
                    .padding(.bottom, 4)
                    .onTapGesture { store.dismissError() }
                }
                NavBar()
            }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .easeOut(duration: 0.2), value: store.errorToast?.id)
    }

    @ViewBuilder
    private var routeContent: some View {
        if store.isOnboarding {
            OnboardingView()
        } else {
            ZStack {
                routeView(for: store.route)
                    .id(routeIdentity(for: store.route))
                    .transition(routeTransition)
            }
            .animation(routeAnimation, value: store.route)
        }
    }

    @ViewBuilder
    private func routeView(for route: PanelRoute) -> some View {
        switch route {
        case .home:
            HomeRouteView()
        case .composer(let mode):
            ComposerView(mode: mode)
        case .calendar:
            CalendarView()
        case .settings:
            SettingsView()
        }
    }

    private func routeIdentity(for route: PanelRoute) -> String {
        switch route {
        case .home: "home"
        case .composer(let mode): "composer-\(mode)"
        case .calendar: "calendar"
        case .settings: "settings"
        }
    }

    private var routeTransition: AnyTransition {
        let offset: CGFloat = store.routeDirection == .push ? 8 : -8
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(x: offset)),
            removal: .opacity
        )
    }

    private var routeAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .easeOut(duration: 0.18)
    }
}

struct HomeRouteView: View {
    @Environment(NotchStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var expanded: Bool { store.isExpanded }

    var body: some View {
        VStack(alignment: .leading, spacing: NotchMetrics.sectionGap) {
            PanelHeader()
                .padding(.top, 8)

            panelBody(index: 1) {
                divider
                if store.isLoadingHome {
                    VStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { _ in SkeletonRow() }
                    }
                } else {
                    TodaySummary()
                }
            }

            panelBody(index: 2) { divider }

            panelBody(index: 3) {
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

    @ViewBuilder
    private func panelBody(index: Int, @ViewBuilder content: () -> some View) -> some View {
        content()
            .opacity(expanded ? 1 : 0)
            .offset(y: expanded ? 0 : 6)
            .animation(
                NotchMetrics.sectionRevealAnimation(index: index, expanded: expanded, reduceMotion: reduceMotion),
                value: expanded
            )
    }
}
