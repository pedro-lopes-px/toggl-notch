import SwiftUI

struct GeneralSettingsPane: View {
    @Environment(NotchStore.self) private var store
    @State private var showTokenField = false
    @State private var tokenText = ""
    @State private var showWorkspacePopover = false

    var body: some View {
        @Bindable var store = store

        ScrollView {
            Form {
                Section("Workspace") {
                    LabeledContent("Active workspace") {
                        Button(store.workspaceRepo.activeWorkspace?.name ?? "—") {
                            showWorkspacePopover = true
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }

                    LabeledContent("Account") {
                        Text(store.workspaceRepo.user?.email ?? "—")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("API") {
                    LabeledContent("Token") {
                        if showTokenField {
                            SecureField("Token", text: $tokenText)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 220)
                                .onSubmit(saveToken)
                        } else {
                            HStack(spacing: 8) {
                                Text("••••••••")
                                    .foregroundStyle(.secondary)
                                Button("Replace…") { showTokenField = true }
                                    .buttonStyle(.link)
                            }
                        }
                    }
                }

                Section("App") {
                    Picker("Open panel", selection: $store.panelOpenTrigger) {
                        ForEach(PanelOpenTrigger.allCases) { trigger in
                            Text(trigger.label).tag(trigger)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Launch at login", isOn: $store.launchAtLogin)

                    Toggle("Show in menu bar", isOn: $store.showMenuBar)
                }

                Section {
                    Button("Quit Toggl Notch", role: .destructive) {
                        NSApp.terminate(nil)
                    }
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal, NotchMetrics.panelPadding)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
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
            try? await store.connect(token: tokenText)
            showTokenField = false
            tokenText = ""
        }
    }
}

#Preview {
    GeneralSettingsPane()
        .environment(NotchStore(useMockData: true))
        .frame(width: 520, height: 480)
}
