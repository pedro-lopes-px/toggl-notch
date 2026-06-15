import SwiftUI

struct ProjectPickerRow: View {
    @Binding var selectedProjectID: String?
    var compact: Bool = false
    @Environment(NotchStore.self) private var store
    @State private var showPopover = false
    @State private var search = ""

    private var project: Project? { store.projectRepo.project(for: selectedProjectID) }
    private var clientLabel: String? { project?.resolvedClientName(using: store.clientRepo) }

    var body: some View {
        Button { showPopover.toggle() } label: {
            Group {
                if compact {
                    HStack(spacing: 0) {
                        HStack(spacing: 4) {
                            projectIndicator
                            projectLabel(compact: true)
                            pickerChevron
                        }
                        Spacer(minLength: 0)
                    }
                } else {
                    HStack(spacing: 8) {
                        projectIndicator
                        projectLabel(compact: false)
                        Spacer(minLength: 0)
                        pickerChevron
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: NotchMetrics.rowHeight)
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            ProjectPickerPopover(search: $search, selectedProjectID: $selectedProjectID, isPresented: $showPopover)
        }
    }

    @ViewBuilder
    private var projectIndicator: some View {
        if let project {
            ProjectDot(color: project.color, size: 8)
        } else {
            Circle()
                .strokeBorder(NotchColors.textTertiary, lineWidth: 1)
                .frame(width: 8, height: 8)
        }
    }

    @ViewBuilder
    private func projectLabel(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(project?.name ?? "No project")
                .font(.system(size: 13))
                .foregroundStyle(NotchColors.textPrimary)
                .lineLimit(1)
            if let clientLabel, !compact {
                Text(clientLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(NotchColors.textTertiary)
                    .lineLimit(1)
            }
        }
    }

    private var pickerChevron: some View {
        Image(systemName: "chevron.up.chevron.down")
            .font(.system(size: 10))
            .foregroundStyle(NotchColors.textTertiary)
    }
}

private struct ProjectClientGroup: Identifiable {
    let clientName: String
    let projects: [Project]
    let showsHeader: Bool

    var id: String { clientName }

    init(clientName: String, projects: [Project], showsHeader: Bool = true) {
        self.clientName = clientName
        self.projects = projects
        self.showsHeader = showsHeader
    }
}

struct ProjectPickerPopover: View {
    @Binding var search: String
    @Binding var selectedProjectID: String?
    @Binding var isPresented: Bool
    @Environment(NotchStore.self) private var store

    private static let noClientLabel = "No client"
    private static let rowHeight: CGFloat = 28
    private static let sectionHeaderHeight: CGFloat = 22

    private var groups: [ProjectClientGroup] {
        let q = search.lowercased()
        let projects = store.projects.filter { project in
            guard q.isEmpty else {
                let clientName = project.resolvedClientName(using: store.clientRepo) ?? ""
                return project.name.lowercased().contains(q) || clientName.lowercased().contains(q)
            }
            return true
        }
        var grouped: [String: [Project]] = [:]
        for project in projects {
            let clientName = project.resolvedClientName(using: store.clientRepo) ?? Self.noClientLabel
            grouped[clientName, default: []].append(project)
        }
        return grouped
            .map { name, projects in
                ProjectClientGroup(
                    clientName: name,
                    projects: projects.sorted { $0.name < $1.name },
                    showsHeader: name != Self.noClientLabel
                )
            }
            .sorted { lhs, rhs in
                if !lhs.showsHeader { return false }
                if !rhs.showsHeader { return true }
                return lhs.clientName.localizedCaseInsensitiveCompare(rhs.clientName) == .orderedAscending
            }
    }

    private var popoverHeight: CGFloat {
        let projectRows = CGFloat(groups.reduce(0) { $0 + $1.projects.count })
        let sectionHeaders = CGFloat(groups.filter(\.showsHeader).count) * Self.sectionHeaderHeight
        let noProjectRow = Self.rowHeight
        return min(projectRows * Self.rowHeight + sectionHeaders + noProjectRow + 40, 220)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Search", text: $search)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(8)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    pickerRow(name: "No project", dot: nil) {
                        selectedProjectID = nil
                        isPresented = false
                    }
                    ForEach(groups) { group in
                        if group.showsHeader {
                            Text(group.clientName.uppercased())
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(NotchColors.textTertiary)
                                .padding(.horizontal, 8)
                                .frame(height: Self.sectionHeaderHeight, alignment: .leading)
                        }
                        ForEach(group.projects) { project in
                            pickerRow(name: project.name, dot: project.color) {
                                selectedProjectID = project.id
                                isPresented = false
                            }
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .frame(width: 240, height: popoverHeight)
        }
        .task {
            await store.clientRepo.refreshIfNeeded(force: true)
            await store.projectRepo.refreshIfNeeded(force: true)
        }
    }

    private func pickerRow(name: String, dot: Color?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let dot {
                    ProjectDot(color: dot, size: 6)
                } else {
                    Circle().strokeBorder(NotchColors.textTertiary, lineWidth: 1).frame(width: 6, height: 6)
                }
                Text(name)
                    .font(.system(size: 13))
                    .foregroundStyle(NotchColors.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
    }
}

extension Project {
    func resolvedClientName(using clientRepo: ClientRepo) -> String? {
        if let clientName, !clientName.isEmpty { return clientName }
        return clientRepo.client(for: clientID)?.name
    }
}
