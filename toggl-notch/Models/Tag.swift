import Foundation

nonisolated struct Tag: Identifiable, Hashable, Codable, Sendable {
    let id: Int
    var name: String
    let workspaceID: Int

    enum CodingKeys: String, CodingKey {
        case id, name
        case workspaceID = "workspace_id"
    }
}
