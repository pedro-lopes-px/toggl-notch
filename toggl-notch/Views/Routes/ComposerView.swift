import SwiftUI

struct ComposerView: View {
    let mode: ComposerMode

    @Environment(NotchStore.self) private var store
    @State private var description = ""
    @State private var projectID: String?
    @State private var tagIDs: [Int] = []
    @State private var startedAt = Date.now
    @State private var endedAt = Date.now
    @State private var deleteConfirm = false
    @State private var deleteConfirmTask: Task<Void, Never>?
    @FocusState private var descriptionFocused: Bool

    private var isEdit: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var isRunningEdit: Bool {
        guard case .edit(let entry) = mode else { return false }
        return store.runningEntry?.id == entry.id
    }

    private var durationSeconds: Int {
        max(0, Int(endedAt.timeIntervalSince(startedAt)))
    }

    private var isValidRange: Bool { endedAt >= startedAt }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RouteHeader(title: modeTitle)

            VStack(alignment: .leading, spacing: 12) {
                descriptionField
                ProjectPickerRow(selectedProjectID: $projectID)
                TagPickerRow(selectedTagIDs: $tagIDs)
                if isEdit {
                    TimeFieldRow(
                        startedAt: $startedAt,
                        endedAt: $endedAt,
                        isValid: isValidRange
                    )
                    if durationSeconds > 12 * 3600 {
                        Text("Long entry — over 12 hours")
                            .font(.system(size: 11))
                            .foregroundStyle(NotchColors.textTertiary)
                    }
                }
            }
            .padding(.horizontal, NotchMetrics.panelPadding)
            .padding(.top, 12)

            Spacer(minLength: 0)

            footer
                .padding(.horizontal, NotchMetrics.panelPadding)
                .padding(.bottom, 8)
        }
        .onAppear(perform: loadMode)
    }

    private var modeTitle: String {
        switch mode {
        case .new, .continue: "New entry"
        case .edit: "Edit entry"
        }
    }

    private var descriptionField: some View {
        VStack(spacing: 0) {
            TextField("What are you working on?", text: $description)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(NotchColors.textPrimary)
                .focused($descriptionFocused)
                .onSubmit(primaryAction)
            Rectangle()
                .fill(descriptionFocused ? NotchColors.borderSubtle : .clear)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private var footer: some View {
        if isEdit {
            HStack(spacing: 12) {
                primaryButton(title: "Save", symbol: "checkmark", action: saveEdit)
                    .frame(maxWidth: .infinity)
                deleteButton
            }
            .opacity(isValidRange ? 1 : 0.4)
            .disabled(!isValidRange)
        } else {
            primaryButton(title: "Start", symbol: "play.fill", action: startNew)
                .frame(maxWidth: .infinity)
        }
    }

    private var deleteButton: some View {
        Button(deleteConfirm ? "Delete?" : "Delete") {
            if deleteConfirm {
                deleteEntry()
            } else {
                deleteConfirm = true
                deleteConfirmTask?.cancel()
                deleteConfirmTask = Task {
                    try? await Task.sleep(for: .seconds(2))
                    deleteConfirm = false
                }
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(NotchColors.textTertiary)
        .buttonStyle(.plain)
        .pointerStyle(.link)
    }

    @ViewBuilder
    private func primaryButton(title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(NotchColors.textPrimary)
            .frame(height: 36)
            .frame(maxWidth: .infinity)
            .background(NotchColors.surfaceRaised, in: .rect(cornerRadius: 10))
        }
        .buttonStyle(PressableButtonStyle())
        .pointerStyle(.link)
    }

    private func loadMode() {
        descriptionFocused = true
        if let entry = mode.prefilledEntry {
            description = entry.description
            projectID = entry.projectID
            tagIDs = entry.tagIDs
            startedAt = entry.startedAt
            endedAt = entry.stoppedAt
        }
    }

    private func primaryAction() {
        if isEdit { saveEdit() } else { startNew() }
    }

    private func startNew() {
        store.startEntry(description: description, projectID: projectID, tagIDs: tagIDs)
        store.popToHome()
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            store.collapse()
        }
    }

    private func saveEdit() {
        guard case .edit(var entry) = mode else { return }
        entry.description = description
        entry.projectID = projectID
        entry.tagIDs = tagIDs
        entry.startedAt = startedAt
        entry.durationSeconds = durationSeconds
        let tagNames = store.tagRepo.tagNames(for: tagIDs)
        store.enqueueMutation { [store] in
            _ = try await store.timeEntryRepo.update(entry, tagNames: tagNames)
        }
        store.pop()
    }

    private func deleteEntry() {
        guard case .edit(let entry) = mode else { return }
        store.enqueueMutation { [store] in
            try await store.timeEntryRepo.delete(entry)
        }
        store.pop()
    }
}
