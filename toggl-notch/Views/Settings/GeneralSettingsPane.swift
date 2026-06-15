import SwiftUI

struct GeneralSettingsPane: View {
    @Environment(NotchStore.self) private var store
    @State private var showTokenField = false
    @State private var tokenText = ""
    @State private var showWorkspacePopover = false
    @State private var quitHovering = false

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(alignment: .leading, spacing: NotchMetrics.settingsSectionGap) {
                SettingsSection("Workspace") {
                    VStack(alignment: .leading, spacing: NotchMetrics.settingsRowGap) {
                        SettingsFieldRow("Active workspace") {
                            Button(store.workspaceRepo.activeWorkspace?.name ?? "—") {
                                showWorkspacePopover = true
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(NotchColors.textSecondary)
                        }

                        SettingsFieldRow("Account") {
                            Text(store.workspaceRepo.user?.email ?? "—")
                                .foregroundStyle(NotchColors.textSecondary)
                        }
                    }
                }

                SettingsSection("API") {
                    SettingsFieldRow("Token") {
                        if showTokenField {
                            SecureTokenField(
                                placeholder: "Token",
                                text: $tokenText,
                                onSubmit: saveToken
                            )
                            .frame(maxWidth: 220)
                        } else {
                            HStack(spacing: 8) {
                                Text("••••••••")
                                    .foregroundStyle(NotchColors.textSecondary)
                                Button("Replace…") { showTokenField = true }
                                    .buttonStyle(.link)
                            }
                        }
                    }
                }

                SettingsSection("App") {
                    VStack(alignment: .leading, spacing: NotchMetrics.settingsRowGap) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Open panel")
                                .font(.system(size: 13))
                                .foregroundStyle(NotchColors.textSecondary)

                            Picker("Open panel", selection: $store.panelOpenTrigger) {
                                ForEach(PanelOpenTrigger.allCases) { trigger in
                                    Text(trigger.label).tag(trigger)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }

                        SettingsToggleRow(label: "Launch at login", isOn: $store.launchAtLogin)

                        SettingsToggleRow(label: "Show in menu bar", isOn: $store.showMenuBar)
                    }
                }

                Button("Quit Toggl Notch") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(quitHovering ? NotchColors.accentRedDim : NotchColors.textSecondary)
                .frame(maxWidth: .infinity)
                .pointerStyle(.link)
                .onHover { quitHovering = $0 }
                .animation(.easeOut(duration: 0.12), value: quitHovering)
                .padding(.top, 4)
            }
            .padding(.horizontal, NotchMetrics.panelPadding)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .settingsPaneChrome()
        .safeAreaInset(edge: .bottom) {
            Text(appVersion)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
        }
        .popover(isPresented: $showWorkspacePopover) {
            WorkspaceSwitcherPopover(isPresented: $showWorkspacePopover)
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "Toggl Notch \(v)"
    }

    private func saveToken() {
        Task {
            do {
                try await store.connect(token: tokenText)
                showTokenField = false
                tokenText = ""
            } catch let error as TogglAPIError {
                store.showError(error.userMessage)
            } catch {
                store.showError("Couldn't save token")
            }
        }
    }
}

#Preview {
    GeneralSettingsPane()
        .environment(NotchStore(useMockData: true))
        .frame(width: 520, height: 480)
}
