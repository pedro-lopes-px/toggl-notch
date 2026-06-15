import Foundation

nonisolated struct TimeEntry: Identifiable, Hashable, Codable, Sendable {
    let id: String
    var workspaceID: Int
    var projectID: String?
    var description: String
    var startedAt: Date
    var durationSeconds: Int
    var tagIDs: [Int]

    var isDeepWork: Bool { durationSeconds >= 25 * 60 }

    var stoppedAt: Date {
        startedAt.addingTimeInterval(TimeInterval(durationSeconds))
    }

    static func uniqueKey(description: String, projectID: String?) -> String {
        "\(description.lowercased())|\(projectID ?? "")"
    }
}
