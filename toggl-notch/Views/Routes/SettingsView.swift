import SwiftUI

struct SettingsView: View {
    @Environment(NotchStore.self) private var store
    @State private var selection: SettingsRoute = .general

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RouteHeader(title: "Settings")

            tabBar
                .padding(.horizontal, NotchMetrics.panelPadding)
                .padding(.top, 8)
                .padding(.bottom, 10)

            paneContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear {
            if let section = store.route.settingsSection {
                selection = section
            }
        }
        .onChange(of: selection) { _, section in
            guard store.route.settingsSection != nil else { return }
            store.route = .settings(section)
        }
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(SettingsRoute.allCases) { route in
                    tabButton(route)
                }
            }
        }
    }

    private func tabButton(_ route: SettingsRoute) -> some View {
        let isSelected = selection == route

        return Button {
            selection = route
        } label: {
            HStack(spacing: 5) {
                Image(systemName: route.symbol)
                    .font(.system(size: 11, weight: .medium))
                Text(route.title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
            }
            .foregroundStyle(isSelected ? NotchColors.textPrimary : NotchColors.textTertiary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(isSelected ? NotchColors.surfaceRaised : NotchColors.surfaceHover.opacity(0.45))
            }
        }
        .buttonStyle(PressableButtonStyle())
        .pointerStyle(.link)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var paneContent: some View {
        switch selection {
        case .general:
            GeneralSettingsPane()
        case .projects:
            ProjectsSettingsPane()
        case .tags:
            TagsSettingsPane()
        case .clients:
            ClientsSettingsPane()
        }
    }
}

#Preview {
    SettingsView()
        .environment(NotchStore(useMockData: true))
        .frame(width: 400, height: 460)
        .background(NotchColors.surfaceNotch)
}
