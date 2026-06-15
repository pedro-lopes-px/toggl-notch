import SwiftUI

struct RecentEntryEditPopover: View {
    let entry: TimeEntry
    @Binding var isPresented: Bool

    @Environment(NotchStore.self) private var store
    @State private var description: String
    @State private var projectID: String?
    @State private var tagIDs: [Int]
    @State private var startedAt: Date
    @State private var endedAt: Date
    @State private var deleteConfirm = false
    @FocusState private var descriptionFocused: Bool

    init(entry: TimeEntry, isPresented: Binding<Bool>) {
        self.entry = entry
        _isPresented = isPresented
        _description = State(initialValue: entry.description)
        _projectID = State(initialValue: entry.projectID)
        _tagIDs = State(initialValue: entry.tagIDs)
        _startedAt = State(initialValue: entry.startedAt)
        _endedAt = State(initialValue: entry.stoppedAt)
    }

    private var durationSeconds: Int {
        max(0, Int(endedAt.timeIntervalSince(startedAt)))
    }

    private var isValidRange: Bool { endedAt >= startedAt }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit entry")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(NotchColors.textTertiary)

            descriptionField
            ProjectPickerRow(selectedProjectID: $projectID)
            TagPickerRow(selectedTagIDs: $tagIDs)
            TimeFieldRow(startedAt: $startedAt, endedAt: $endedAt, isValid: isValidRange)

            HStack(spacing: 12) {
                Button(deleteConfirm ? "Delete?" : "Delete") {
                    if deleteConfirm {
                        deleteEntry()
                    } else {
                        deleteConfirm = true
                    }
                }
                .font(.system(size: 13))
                .foregroundStyle(NotchColors.textTertiary)
                .buttonStyle(.plain)
                .pointerStyle(.link)

                Spacer(minLength: 0)

                Button("Save") { saveEntry() }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isValidRange ? NotchColors.textPrimary : NotchColors.textTertiary)
                    .buttonStyle(.plain)
                    .pointerStyle(.link)
                    .disabled(!isValidRange)
            }
        }
        .padding(12)
        .frame(width: 280)
        .onAppear { descriptionFocused = true }
    }

    private var descriptionField: some View {
        VStack(spacing: 0) {
            TextField("What were you working on?", text: $description)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(NotchColors.textPrimary)
                .focused($descriptionFocused)
                .onSubmit(saveEntry)
            Rectangle()
                .fill(descriptionFocused ? NotchColors.borderSubtle : .clear)
                .frame(height: 1)
        }
    }

    private func saveEntry() {
        guard isValidRange else { return }
        var updated = entry
        updated.description = description
        updated.projectID = projectID
        updated.tagIDs = tagIDs
        updated.startedAt = startedAt
        updated.durationSeconds = durationSeconds
        let tagNames = store.tagRepo.tagNames(for: tagIDs)
        store.enqueueMutation { [store] in
            _ = try await store.timeEntryRepo.update(updated, tagNames: tagNames)
        }
        isPresented = false
    }

    private func deleteEntry() {
        store.enqueueMutation { [store] in
            try await store.timeEntryRepo.delete(entry)
        }
        isPresented = false
    }
}
