import SwiftUI

/// Route content with transitions and pinned NavBar.
struct PanelContent: View {
    @Environment(NotchStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                if store.isQuotaLimited, let resetsAt = store.quotaResetAt {
                    QuotaLimitBanner(resetsAt: resetsAt)
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .padding(.bottom, 4)
                }

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
                    .contentShape(.rect)
                    .onTapGesture { store.dismissError() }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Dismiss error")
                }
                NavBar()
            }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .easeOut(duration: 0.2), value: store.errorToast?.id)
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .easeOut(duration: 0.2), value: store.isQuotaLimited)
    }

    @ViewBuilder
    private var routeContent: some View {
        if store.isOnboarding {
            if store.hasStoredToken {
                SessionRecoveryView()
            } else {
                OnboardingView()
            }
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
