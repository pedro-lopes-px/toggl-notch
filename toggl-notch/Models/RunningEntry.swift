import Foundation

nonisolated struct RunningEntry: Hashable, Sendable {
    let id: String
    var workspaceID: Int
    var projectID: String?
    var description: String
    let startedAt: Date
    var tagIDs: [Int]
}
