import Foundation

nonisolated struct Workspace: Identifiable, Hashable, Codable, Sendable {
    let id: Int
    let name: String
}

nonisolated struct TogglUser: Hashable, Codable, Sendable {
    let id: Int
    let email: String
    let defaultWorkspaceID: Int

    enum CodingKeys: String, CodingKey {
        case id, email
        case defaultWorkspaceID = "default_workspace_id"
    }
}
