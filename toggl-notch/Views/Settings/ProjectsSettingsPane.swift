import SwiftUI

struct ProjectsSettingsPane: View {
    @Environment(NotchStore.self) private var store
    @State private var creating = false
    @State private var newName = ""
    @FocusState private var createFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            createActionHeader(title: "New Project", action: beginCreate)

            if store.projectRepo.isLoading && store.projects.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.projects.isEmpty {
                ContentUnavailableView("No Projects", systemImage: "folder", description: Text("Create a project to organize your time entries."))
            } else {
                List {
                    ForEach(store.projects) { project in
                        ProjectSettingsRow(project: project)
                    }
                }
                .listStyle(.inset)
            }

            createBar
        }
        .task { await store.projectRepo.refreshIfNeeded(force: true) }
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
        .padding(.top, 4)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var createBar: some View {
        if creating {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .foregroundStyle(.secondary)
                TextField("Project name", text: $newName)
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
        let color = Project.palette.randomElement() ?? Project.palette[0]
        store.enqueueMutation { [store] in
            _ = try await store.projectRepo.create(name: name, color: color, clientID: nil)
        }
        cancelCreate()
    }
}

struct ProjectSettingsRow: View {
    let project: Project
    @Environment(NotchStore.self) private var store
    @State private var deleteConfirm = false

    var body: some View {
        HStack(spacing: 10) {
            ProjectDot(color: project.color, size: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .lineLimit(1)
                if let client = project.clientName {
                    Text(client)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Text(hoursLabel)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
            Menu {
                Button(deleteConfirm ? "Archive?" : "Archive") { confirmArchive() }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24)
        }
        .padding(.vertical, 2)
    }

    private var hoursLabel: String {
        let seconds = store.projectRepo.hoursThisWeek(for: project.id, entries: store.entries)
        return TimeFormatting.formatDuration(seconds)
    }

    private func confirmArchive() {
        if deleteConfirm {
            store.enqueueMutation { [store] in
                try await store.projectRepo.archive(project)
            }
            deleteConfirm = false
        } else {
            deleteConfirm = true
        }
    }
}

#Preview {
    ProjectsSettingsPane()
        .environment(NotchStore(useMockData: true))
        .frame(width: 520, height: 480)
}
