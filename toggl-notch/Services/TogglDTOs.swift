import Foundation

enum TogglAPIError: Error, Equatable, Sendable {
    case unauthenticated
    /// Per-second burst throttle (HTTP 429).
    case rateLimited
    /// Hourly plan quota (HTTP 402). `resetsAt` comes from `X-Toggl-Quota-Resets-In`.
    case quotaExceeded(resetsAt: Date)
    case serverError(Int)
    case network
    case decoding
    case notFound
    case unknown(String)

    var userMessage: String {
        switch self {
        case .unauthenticated:
            "That token didn't work. Copy it from Toggl Profile → API Token."
        case .network:
            "No internet connection."
        case .decoding:
            "Got an unexpected response from Toggl. Try again."
        case .rateLimited:
            "Too many requests. Wait a moment and try again."
        case .quotaExceeded:
            "Hourly API limit reached. Your token is fine — wait for the reset."
        case .serverError:
            "Toggl is having issues. Try again."
        case .notFound:
            "That token didn't work."
        case .unknown(let detail):
            detail
        }
    }
}

// MARK: - DTOs

nonisolated struct TogglMeDTO: Decodable, Sendable {
    let id: Int
    let email: String
    let defaultWorkspaceID: Int?

    enum CodingKeys: String, CodingKey {
        case id, email
        case defaultWorkspaceID = "default_workspace_id"
    }
}

nonisolated struct TogglWorkspaceDTO: Decodable, Sendable {
    let id: Int
    let name: String
}

nonisolated struct TogglTimeEntryDTO: Decodable, Sendable {
    let id: Int64
    let workspaceID: Int
    let projectID: Int?
    let description: String?
    let start: Date
    let duration: Int
    let tags: [String]?

    enum CodingKeys: String, CodingKey {
        case id, description, start, duration, tags
        case workspaceID = "workspace_id"
        case projectID = "project_id"
    }
}

nonisolated struct TogglProjectDTO: Decodable, Sendable {
    let id: Int
    let name: String
    let color: String?
    let clientID: Int?
    let clientName: String?
    let workspaceID: Int
    let active: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, color, active, cid
        case clientID = "client_id"
        case clientName = "client_name"
        case workspaceID = "workspace_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        color = try c.decodeIfPresent(String.self, forKey: .color)
        clientID = try c.decodeIfPresent(Int.self, forKey: .clientID)
            ?? c.decodeIfPresent(Int.self, forKey: .cid)
        clientName = try c.decodeIfPresent(String.self, forKey: .clientName)
        workspaceID = try c.decode(Int.self, forKey: .workspaceID)
        active = try c.decodeIfPresent(Bool.self, forKey: .active) ?? true
    }
}

nonisolated struct TogglClientDTO: Decodable, Sendable {
    let id: Int
    let name: String
    let workspaceID: Int

    enum CodingKeys: String, CodingKey {
        case id, name, wid
        case workspaceID = "workspace_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        workspaceID = try c.decodeIfPresent(Int.self, forKey: .wid)
            ?? c.decodeIfPresent(Int.self, forKey: .workspaceID)
            ?? 0
    }
}

nonisolated struct TogglTagDTO: Decodable, Sendable {
    let id: Int
    let name: String
    let workspaceID: Int

    enum CodingKeys: String, CodingKey {
        case id, name
        case workspaceID = "workspace_id"
    }
}

// MARK: - Request bodies

nonisolated struct StartEntryBody: Encodable, Sendable {
    let description: String
    let projectID: Int?
    let tags: [String]
    let duration: Int
    let start: Date
    let createdWith: String
    let workspaceID: Int

    enum CodingKeys: String, CodingKey {
        case description, tags, duration, start
        case projectID = "project_id"
        case createdWith = "created_with"
        case workspaceID = "workspace_id"
    }
}

nonisolated struct UpdateEntryBody: Encodable, Sendable {
    let description: String
    let projectID: Int?
    let tags: [String]
    let start: Date
    let duration: Int

    enum CodingKeys: String, CodingKey {
        case description, tags, start, duration
        case projectID = "project_id"
    }
}

nonisolated struct CreateProjectBody: Encodable, Sendable {
    let name: String
    let color: String
    let clientID: Int?
    let active: Bool

    enum CodingKeys: String, CodingKey {
        case name, color, active
        case clientID = "client_id"
    }
}

nonisolated struct UpdateProjectBody: Encodable, Sendable {
    let name: String
    let color: String
    let clientID: Int?
    let active: Bool

    enum CodingKeys: String, CodingKey {
        case name, color, active
        case clientID = "client_id"
    }
}

nonisolated struct CreateClientBody: Encodable, Sendable {
    let name: String
}

nonisolated struct UpdateClientBody: Encodable, Sendable {
    let name: String
}

nonisolated struct CreateTagBody: Encodable, Sendable {
    let name: String
}

nonisolated struct UpdateTagBody: Encodable, Sendable {
    let name: String
}

// MARK: - JSON coding

nonisolated enum TogglJSONCoding {
    static func parseDate(_ string: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: string) { return date }
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return standard.date(from: string)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try makeDecoder().decode(type, from: data)
    }

    static func encode<T: Encodable>(_ value: T) throws -> Data {
        try makeEncoder().encode(value)
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = parseDate(string) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
        }
        return decoder
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            try container.encode(formatter.string(from: date))
        }
        return encoder
    }
}

// MARK: - Mapping

nonisolated enum TogglDTOMapper {
    static func user(from dto: TogglMeDTO) -> TogglUser {
        TogglUser(
            id: dto.id,
            email: dto.email,
            defaultWorkspaceID: dto.defaultWorkspaceID ?? 0
        )
    }

    static func workspace(from dto: TogglWorkspaceDTO) -> Workspace {
        Workspace(id: dto.id, name: dto.name)
    }

    static func client(from dto: TogglClientDTO) -> Client {
        Client(id: dto.id, name: dto.name, workspaceID: dto.workspaceID)
    }

    static func tag(from dto: TogglTagDTO) -> Tag {
        Tag(id: dto.id, name: dto.name, workspaceID: dto.workspaceID)
    }

    static func timeEntry(from dto: TogglTimeEntryDTO, tagNameToID: [String: Int] = [:]) -> TimeEntry? {
        let duration: Int
        if dto.duration < 0 {
            return nil
        } else {
            duration = dto.duration
        }
        let tagIDs = (dto.tags ?? []).compactMap { tagNameToID[$0] }
        return TimeEntry(
            id: String(dto.id),
            workspaceID: dto.workspaceID,
            projectID: dto.projectID.map(String.init),
            description: dto.description ?? "",
            startedAt: dto.start,
            durationSeconds: duration,
            tagIDs: tagIDs
        )
    }

    static func runningEntry(from dto: TogglTimeEntryDTO, tagNameToID: [String: Int] = [:]) -> RunningEntry? {
        guard dto.duration < 0 else { return nil }
        let tagIDs = (dto.tags ?? []).compactMap { tagNameToID[$0] }
        return RunningEntry(
            id: String(dto.id),
            workspaceID: dto.workspaceID,
            projectID: dto.projectID.map(String.init),
            description: dto.description ?? "",
            startedAt: dto.start,
            tagIDs: tagIDs
        )
    }
}
