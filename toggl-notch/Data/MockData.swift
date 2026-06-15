import SwiftUI

/// Static seed data used when no API token is configured.
enum MockData {
    static let clients: [Client] = [
        Client(id: 1, name: "Pixelmatters", workspaceID: 0),
        Client(id: 2, name: "Atlas", workspaceID: 0),
    ]

    static let projects: [Project] = [
        Project(id: "p1", name: "Pixelmatters Website", color: Color(red: 0.478, green: 0.549, blue: 0.941), clientID: 1, clientName: "Pixelmatters"),
        Project(id: "p2", name: "Client — Atlas App", color: Color(red: 0.788, green: 0.627, blue: 0.416), clientID: 2, clientName: "Atlas"),
        Project(id: "p3", name: "Design System", color: Color(red: 0.608, green: 0.549, blue: 0.878), clientID: 1, clientName: "Pixelmatters"),
        Project(id: "p4", name: "Internal Tools", color: Color(red: 0.435, green: 0.722, blue: 0.659)),
        Project(id: "p5", name: "Research", color: Color(red: 0.690, green: 0.471, blue: 0.549)),
    ]

    static let runningEntry: RunningEntry? = RunningEntry(
        id: "mock-running",
        workspaceID: 0,
        projectID: "p2",
        description: "Onboarding flow refinements",
        startedAt: Date.now.addingTimeInterval(-(47 * 60 + 23)),
        tagIDs: []
    )

    static let entries: [TimeEntry] = [
        TimeEntry(id: "e1", workspaceID: 0, projectID: "p1", description: "Design review notes",
                  startedAt: Date.now.addingTimeInterval(-2 * 3600), durationSeconds: 2280, tagIDs: []),
        TimeEntry(id: "e2", workspaceID: 0, projectID: "p3", description: "Component API cleanup",
                  startedAt: Date.now.addingTimeInterval(-4 * 3600), durationSeconds: 4320, tagIDs: []),
        TimeEntry(id: "e3", workspaceID: 0, projectID: "p4", description: "Sprint planning",
                  startedAt: Date.now.addingTimeInterval(-5 * 3600), durationSeconds: 1560, tagIDs: []),
        TimeEntry(id: "e4", workspaceID: 0, projectID: "p4", description: "Bug triage",
                  startedAt: Date.now.addingTimeInterval(-6 * 3600), durationSeconds: 1080, tagIDs: []),
        TimeEntry(id: "e5", workspaceID: 0, projectID: "p1", description: "Landing page copy pass",
                  startedAt: Date.now.addingTimeInterval(-7 * 3600), durationSeconds: 3120, tagIDs: []),
        TimeEntry(id: "e6", workspaceID: 0, projectID: "p3", description: "Figma handoff",
                  startedAt: Date.now.addingTimeInterval(-8 * 3600), durationSeconds: 3900, tagIDs: []),
    ]
}
