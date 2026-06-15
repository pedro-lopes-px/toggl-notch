import SwiftUI

struct TagsSettingsPane: View {
    @Environment(NotchStore.self) private var store
    @State private var creating = false
    @State private var newName = ""
    @FocusState private var createFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            createActionHeader(title: "New Tag", action: beginCreate)

            if store.tagRepo.isLoading && store.tagRepo.tags.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.tagRepo.tags.isEmpty {
                ContentUnavailableView("No Tags", systemImage: "tag", description: Text("Create tags to categorize your time entries."))
            } else {
                List {
                    ForEach(store.tagRepo.tags) { tag in
                        TagSettingsRow(tag: tag)
                            .settingsListRowChrome()
                    }
                }
                .listStyle(.plain)
                .settingsPaneChrome()
            }

            createBar
        }
        .task { await store.tagRepo.refreshIfNeeded(force: true) }
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
                TextField("Tag name", text: $newName)
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
            _ = try await store.tagRepo.create(name: name)
        }
        cancelCreate()
    }
}

struct TagSettingsRow: View {
    let tag: Tag
    @Environment(NotchStore.self) private var store
    @State private var deleteConfirm = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "tag")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(tag.name)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(usageLabel)
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

    private var usageLabel: String {
        let count = store.tagRepo.usageCountThisMonth(tagID: tag.id, entries: store.entries)
        return count == 1 ? "1 entry" : "\(count) entries"
    }

    private func confirmDelete() {
        if deleteConfirm {
            store.enqueueMutation { [store] in
                try await store.tagRepo.delete(tag)
            }
            deleteConfirm = false
        } else {
            deleteConfirm = true
        }
    }
}

#Preview {
    TagsSettingsPane()
        .environment(NotchStore(useMockData: true))
        .frame(width: 520, height: 480)
}
