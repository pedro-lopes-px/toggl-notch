import SwiftUI

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
