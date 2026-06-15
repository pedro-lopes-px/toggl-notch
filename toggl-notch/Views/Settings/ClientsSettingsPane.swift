import SwiftUI

struct ClientsSettingsPane: View {
    @Environment(NotchStore.self) private var store
    @State private var creating = false
    @State private var newName = ""
    @FocusState private var createFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            createActionHeader(title: "New Client", action: beginCreate)

            if store.clientRepo.isLoading && store.clientRepo.clients.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.clientRepo.clients.isEmpty {
                ContentUnavailableView("No Clients", systemImage: "person.2", description: Text("Create clients to group your projects."))
            } else {
                List {
                    ForEach(store.clientRepo.clients) { client in
                        ClientSettingsRow(client: client)
                            .settingsListRowChrome()
                    }
                }
                .listStyle(.plain)
                .settingsPaneChrome()
            }

            createBar
        }
        .task { await store.clientRepo.refreshIfNeeded(force: true) }
    }

    private func createActionHeader(title: String, action: @escaping () -> Void) -> some View {
        HStack {
            Spacer(minLength: 0)
            Button(title, systemImage: "plus", action: action)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(NotchColors.textSecondary)
                .buttonStyle(.plain)
                .pointerStyle(.link)
        }
        .padding(.horizontal, NotchMetrics.panelPadding)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var createBar: some View {
        if creating {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .foregroundStyle(.secondary)
                TextField("Client name", text: $newName)
                    .textFieldStyle(.plain)
                    .focused($createFocused)
                    .onSubmit(submitCreate)
                Button("Cancel") { cancelCreate() }
                    .buttonStyle(.link)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .onAppear { createFocused = true }
            .onExitCommand(perform: cancelCreate)
        }
    }

    private func beginCreate() {
        creating = true
        newName = ""
    }

    private func cancelCreate() {
        creating = false
        newName = ""
    }

    private func submitCreate() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { cancelCreate(); return }
        store.enqueueMutation { [store] in
            _ = try await store.clientRepo.create(name: name)
        }
        cancelCreate()
    }
}

struct ClientSettingsRow: View {
    let client: Client
    @Environment(NotchStore.self) private var store
    @State private var deleteConfirm = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "person")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(client.name)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(projectCountLabel)
                .font(.caption)
                .foregroundStyle(.tertiary)
            Menu {
                Button(deleteConfirm ? "Delete?" : "Delete", role: .destructive) { confirmDelete() }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24)
        }
        .padding(.vertical, 4)
    }

    private var projectCountLabel: String {
        let count = store.clientRepo.projectCount(for: client.id, projects: store.projects)
        return count == 1 ? "1 project" : "\(count) projects"
    }

    private func confirmDelete() {
        if deleteConfirm {
            store.enqueueMutation { [store] in
                try await store.clientRepo.delete(client)
            }
            deleteConfirm = false
        } else {
            deleteConfirm = true
        }
    }
}

#Preview {
    ClientsSettingsPane()
        .environment(NotchStore(useMockData: true))
        .frame(width: 520, height: 480)
}
