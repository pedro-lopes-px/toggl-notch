import SwiftUI

struct EntryRow: View {
    let entry: TimeEntry
    @Environment(NotchStore.self) private var store
    @State private var hovering = false
    @State private var playHovering = false
    @State private var editHovering = false
    @State private var showEditPopover = false

    private var project: Project? {
        store.projectRepo.project(for: entry.projectID)
    }

    private var projectName: String? {
        guard let name = project?.name, !name.isEmpty else { return nil }
        return name
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                ProjectDot(color: project?.color ?? .gray, size: 6)

                entryLabels
            }

            Spacer(minLength: 8)

            Text(TimeFormatting.formatDuration(entry.durationSeconds))
                .font(.system(size: 12))
                .monospacedDigit()
                .foregroundStyle(NotchColors.textSecondary)

            Button {
                showEditPopover = true
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(editHovering ? NotchColors.textPrimary : NotchColors.textTertiary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0)
            .animation(.easeOut(duration: 0.12), value: hovering)
            .onHover { editHovering = $0 }
            .accessibilityLabel("Edit entry")
            .popover(isPresented: $showEditPopover, arrowEdge: .top) {
                RecentEntryEditPopover(entry: entry, isPresented: $showEditPopover)
            }
            .onChange(of: showEditPopover) { _, isOpen in
                store.isEditingRecentEntry = isOpen
            }

            Button {
                store.continueEntry(entry)
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(playHovering ? NotchColors.accentGreen : NotchColors.textTertiary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0)
            .animation(.easeOut(duration: 0.12), value: hovering)
            .onHover { playHovering = $0 }
            .accessibilityLabel("Continue entry")
        }
        .padding(.horizontal, 8)
        .frame(height: NotchMetrics.rowHeight)
        .frame(maxWidth: .infinity)
        .background(hovering ? NotchColors.surfaceHover : .clear, in: .rect(cornerRadius: 8))
        .contentShape(.rect)
        .onTapGesture { showEditPopover = true }
        .onHover { hovering = $0 }
        .pointerStyle(.link)
        .animation(.easeOut(duration: 0.15), value: hovering)
    }

    private var entryLabels: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(entry.description)
                .font(.system(size: 13))
                .foregroundStyle(NotchColors.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
            if let projectName {
                Text(projectName)
                    .font(.system(size: 11))
                    .foregroundStyle(NotchColors.textTertiary)
                    .lineLimit(1)
            }
        }
    }
}

#Preview {
    EntryRow(entry: MockData.entries[1])
        .environment(NotchStore())
        .padding()
        .frame(width: 380)
        .background(.black)
}
