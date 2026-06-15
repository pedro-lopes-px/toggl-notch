import SwiftUI

/// Header: running timer with project + description + Stop, or an idle composer
/// with description, project/tag pickers, and Start on the home shell.
struct PanelHeader: View {
    @Environment(NotchStore.self) private var store
    @State private var showWorkspacePopover = false

    private var leadingMaxWidth: CGFloat {
        NotchMetrics.expandedLeadingSectionMaxWidth(
            shellWidth: NotchMetrics.shellWidth(notchWidth: store.notchSize.width, expanded: true),
            notchWidth: store.notchSize.width
        )
    }

    private var showWorkspaceChip: Bool {
        store.workspaceRepo.workspaces.count > 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if store.browsingDiffersFromRunning, let name = store.runningWorkspaceName {
                Text("Timer running in \(name)")
                    .font(.system(size: 11))
                    .foregroundStyle(NotchColors.textTertiary)
            }

            if store.runningEntry != nil {
                runningHeader
            } else {
                PanelHeaderIdle(store: store, showWorkspaceChip: showWorkspaceChip, showWorkspacePopover: $showWorkspacePopover)
            }
        }
        .popover(isPresented: $showWorkspacePopover) {
            WorkspaceSwitcherPopover(isPresented: $showWorkspacePopover)
        }
    }

    private var runningHeader: some View {
        HStack(alignment: .top, spacing: 8) {
            PanelHeaderLeading(showWorkspaceChip: showWorkspaceChip, showWorkspacePopover: $showWorkspacePopover)
                .frame(maxWidth: leadingMaxWidth, alignment: .leading)
            Spacer(minLength: 0)
            PanelHeaderTrailing()
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}

struct PanelHeaderIdle: View {
    @Bindable var store: NotchStore
    let showWorkspaceChip: Bool
    @Binding var showWorkspacePopover: Bool
    @FocusState private var descriptionFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showWorkspaceChip, let workspace = store.workspaceRepo.activeWorkspace {
                workspaceChip(workspace.name)
            }

            HStack(alignment: .center, spacing: 12) {
                descriptionField
                    .frame(maxWidth: .infinity, alignment: .leading)
                CircularIconButton(
                    systemName: "play.fill",
                    label: "Start timer",
                    hoverTint: NotchColors.accentGreen,
                    iconSize: 11,
                    action: store.startDraftEntry
                )
            }

            HStack(alignment: .center, spacing: 8) {
                ProjectPickerRow(selectedProjectID: $store.draftProjectID, compact: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TagPickerRow(selectedTagIDs: $store.draftTagIDs, compact: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var descriptionField: some View {
        VStack(spacing: 0) {
            TextField("What are you working on?", text: $store.draftDescription)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(NotchColors.textPrimary)
                .focused($descriptionFocused)
                .disabled(store.isEditingRecentEntry)
                .onSubmit {
                    guard !store.isEditingRecentEntry else { return }
                    store.startDraftEntry()
                }
            Rectangle()
                .fill(descriptionFocused ? NotchColors.borderSubtle : .clear)
                .frame(height: 1)
        }
    }

    private func workspaceChip(_ name: String) -> some View {
        Button { showWorkspacePopover = true } label: {
            HStack(spacing: 4) {
                Text(name.uppercased())
                    .font(.system(size: 11, weight: .medium))
                    .kerning(0.7)
                    .foregroundStyle(NotchColors.textTertiary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(NotchColors.textTertiary)
            }
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
    }
}

struct PanelHeaderLeading: View {
    @Environment(NotchStore.self) private var store
    @Environment(\.morphNamespace) private var morph
    let showWorkspaceChip: Bool
    @Binding var showWorkspacePopover: Bool

    private var hasRunningDescription: Bool {
        guard let running = store.runningEntry else { return false }
        return !running.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var projectLineIndent: CGFloat {
        NotchMetrics.statusDotSize + NotchMetrics.expandedHeaderItemSpacing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if store.runningEntry != nil {
                if showWorkspaceChip, let workspace = store.workspaceRepo.activeWorkspace {
                    workspaceChip(workspace.name)
                }

                HStack(alignment: .center, spacing: NotchMetrics.expandedHeaderItemSpacing) {
                    statusIndicator
                    TruncatingLine(
                        text: store.collapsedWorkTitle,
                        font: .system(size: 15, weight: .semibold),
                        color: NotchColors.textPrimary,
                        morphID: .title,
                        morphNamespace: morph,
                        morphIsSource: store.isExpanded
                    )
                }

                if hasRunningDescription, let project = store.runningProject {
                    TruncatingLine(
                        text: project.name,
                        font: .system(size: 12),
                        color: NotchColors.textSecondary
                    )
                    .padding(.leading, projectLineIndent)
                }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if let project = store.runningProject {
            ProjectDot(color: project.color, size: NotchMetrics.statusDotSize)
        } else {
            ActiveDot(active: true, offline: store.isOffline)
                .frame(width: NotchMetrics.statusDotSize, height: NotchMetrics.statusDotSize)
        }
    }

    private func workspaceChip(_ name: String) -> some View {
        Button { showWorkspacePopover = true } label: {
            HStack(spacing: 4) {
                Text(name.uppercased())
                    .font(.system(size: 11, weight: .medium))
                    .kerning(0.7)
                    .foregroundStyle(NotchColors.textTertiary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(NotchColors.textTertiary)
            }
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
    }
}

struct PanelHeaderTrailing: View {
    @Environment(NotchStore.self) private var store
    @Environment(\.morphNamespace) private var morph

    var body: some View {
        HStack(spacing: 8) {
            if let running = store.runningEntry {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let elapsed = max(0, Int(context.date.timeIntervalSince(running.startedAt)))
                    Text(TimeFormatting.formatTimer(elapsed))
                        .font(.system(size: 20, weight: .light))
                        .monospacedDigit()
                        .foregroundStyle(NotchColors.textPrimary)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .morphMatched(.timer, in: morph, properties: .position, anchor: .trailing, isSource: store.isExpanded)

                CircularIconButton(
                    systemName: "stop.fill",
                    label: "Stop timer",
                    hoverTint: NotchColors.accentRedDim,
                    iconSize: 10,
                    action: store.stopTimer
                )
                .opacity(store.isExpanded ? 1 : 0)
                .animation(.easeOut(duration: 0.12).delay(0.06), value: store.isExpanded)
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        PanelHeader().environment(NotchStore())
        PanelHeader().environment(NotchStore(useMockData: true))
    }
    .padding()
    .frame(width: 380)
    .background(.black)
}
