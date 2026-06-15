import SwiftUI
import ServiceManagement

struct GeneralSettingsPane: View {
    @Environment(NotchStore.self) private var store
    @State private var showTokenField = false
    @State private var tokenText = ""
    @State private var showWorkspacePopover = false

    var body: some View {
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
                    Picker("Open panel", selection: Binding(
                        get: { store.panelOpenTrigger },
                        set: { store.panelOpenTrigger = $0 }
                    )) {
                        ForEach(PanelOpenTrigger.allCases) { trigger in
                            Text(trigger.label).tag(trigger)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Launch at login", isOn: Binding(
                        get: { store.launchAtLogin },
                        set: { store.setLaunchAtLogin($0) }
                    ))

                    Toggle("Show in menu bar", isOn: Binding(
                        get: { store.showMenuBar },
                        set: { store.showMenuBar = $0 }
                    ))
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

struct WorkspaceSwitcherPopover: View {
    @Binding var isPresented: Bool
    @Environment(NotchStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(store.workspaceRepo.workspaces) { workspace in
                Button {
                    isPresented = false
                    Task { await store.switchWorkspace(workspace.id) }
                } label: {
                    HStack {
                        Text(workspace.name)
                            .font(.system(size: 13))
                            .foregroundStyle(NotchColors.textPrimary)
                        Spacer(minLength: 0)
                        if workspace.id == store.workspaceRepo.activeWorkspaceID {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12))
                                .foregroundStyle(NotchColors.textPrimary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
            }
        }
        .frame(width: 220)
        .padding(.vertical, 4)
    }
}

extension NotchStore {
    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin = enabled
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {}
        }
    }
}

#Preview {
    GeneralSettingsPane()
        .environment(NotchStore(useMockData: true))
        .frame(width: 520, height: 480)
}
