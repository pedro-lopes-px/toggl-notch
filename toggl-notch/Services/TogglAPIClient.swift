import Foundation

actor TogglAPIClient {
    static let baseURL = URL(string: "https://api.track.toggl.com/api/v9")!

    private let session: URLSession
    private var tokenProvider: @Sendable () -> String?

    init(session: URLSession = .shared, tokenProvider: @escaping @Sendable () -> String? = { KeychainStore.readToken() }) {
        self.session = session
        self.tokenProvider = tokenProvider
    }

    func setTokenProvider(_ provider: @escaping @Sendable () -> String?) {
        tokenProvider = provider
    }

    // MARK: - Me

    func fetchMe() async throws -> TogglUser {
        let dto: TogglMeDTO = try await request(path: "/me")
        return TogglDTOMapper.user(from: dto)
    }

    func fetchWorkspaces() async throws -> [Workspace] {
        let dtos: [TogglWorkspaceDTO] = try await request(path: "/me/workspaces")
        return dtos.map(TogglDTOMapper.workspace)
    }

    // MARK: - Time entries

    func fetchCurrentEntry() async throws -> TogglTimeEntryDTO? {
        do {
            return try await request(path: "/me/time_entries/current")
        } catch TogglAPIError.notFound {
            return nil
        }
    }

    func fetchTimeEntries(start: Date, end: Date) async throws -> [TogglTimeEntryDTO] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let startStr = formatter.string(from: start)
        let endStr = formatter.string(from: end)
        let path = "/me/time_entries?start_date=\(startStr)&end_date=\(endStr)"
        return try await request(path: path)
    }

    func startEntry(workspaceID: Int, description: String, projectID: Int?, tags: [String]) async throws -> TogglTimeEntryDTO {
        let body = StartEntryBody(
            description: description,
            projectID: projectID,
            tags: tags,
            duration: -1,
            start: .now,
            createdWith: "Toggl Notch",
            workspaceID: workspaceID
        )
        return try await request(method: "POST", path: "/workspaces/\(workspaceID)/time_entries", body: body)
    }

    func stopEntry(workspaceID: Int, entryID: Int64) async throws -> TogglTimeEntryDTO {
        try await request(method: "PATCH", path: "/workspaces/\(workspaceID)/time_entries/\(entryID)/stop")
    }

    func updateEntry(workspaceID: Int, entryID: Int64, body: UpdateEntryBody) async throws -> TogglTimeEntryDTO {
        try await request(method: "PUT", path: "/workspaces/\(workspaceID)/time_entries/\(entryID)", body: body)
    }

    func deleteEntry(workspaceID: Int, entryID: Int64) async throws {
        let _: EmptyResponse = try await request(method: "DELETE", path: "/workspaces/\(workspaceID)/time_entries/\(entryID)")
    }

    // MARK: - Projects

    func fetchProjects(workspaceID: Int) async throws -> [TogglProjectDTO] {
        try await request(path: "/workspaces/\(workspaceID)/projects?active=true")
    }

    func createProject(workspaceID: Int, body: CreateProjectBody) async throws -> TogglProjectDTO {
        try await request(method: "POST", path: "/workspaces/\(workspaceID)/projects", body: body)
    }

    func updateProject(workspaceID: Int, projectID: Int, body: UpdateProjectBody) async throws -> TogglProjectDTO {
        try await request(method: "PUT", path: "/workspaces/\(workspaceID)/projects/\(projectID)", body: body)
    }

    func deleteProject(workspaceID: Int, projectID: Int) async throws {
        let _: EmptyResponse = try await request(method: "DELETE", path: "/workspaces/\(workspaceID)/projects/\(projectID)")
    }

    // MARK: - Clients

    func fetchClients(workspaceID: Int) async throws -> [TogglClientDTO] {
        try await request(path: "/workspaces/\(workspaceID)/clients")
    }

    func createClient(workspaceID: Int, body: CreateClientBody) async throws -> TogglClientDTO {
        try await request(method: "POST", path: "/workspaces/\(workspaceID)/clients", body: body)
    }

    func updateClient(workspaceID: Int, clientID: Int, body: UpdateClientBody) async throws -> TogglClientDTO {
        try await request(method: "PUT", path: "/workspaces/\(workspaceID)/clients/\(clientID)", body: body)
    }

    func deleteClient(workspaceID: Int, clientID: Int) async throws {
        let _: EmptyResponse = try await request(method: "DELETE", path: "/workspaces/\(workspaceID)/clients/\(clientID)")
    }

    // MARK: - Tags

    func fetchTags(workspaceID: Int) async throws -> [TogglTagDTO] {
        try await request(path: "/workspaces/\(workspaceID)/tags")
    }

    func createTag(workspaceID: Int, body: CreateTagBody) async throws -> TogglTagDTO {
        try await request(method: "POST", path: "/workspaces/\(workspaceID)/tags", body: body)
    }

    func updateTag(workspaceID: Int, tagID: Int, body: UpdateTagBody) async throws -> TogglTagDTO {
        try await request(method: "PUT", path: "/workspaces/\(workspaceID)/tags/\(tagID)", body: body)
    }

    func deleteTag(workspaceID: Int, tagID: Int) async throws {
        let _: EmptyResponse = try await request(method: "DELETE", path: "/workspaces/\(workspaceID)/tags/\(tagID)")
    }

    // MARK: - HTTP

    private struct EmptyResponse: Decodable, Sendable {}

    private func request<T: Decodable & Sendable>(
        method: String = "GET",
        path: String,
        body: (any Encodable)? = nil
    ) async throws -> T {
        guard let token = tokenProvider(), !token.isEmpty else {
            throw TogglAPIError.unauthenticated
        }

        var retries429 = 0
        var retried5xx = false

        while true {
            do {
                return try await performRequest(method: method, path: path, body: body, token: token)
            } catch let error as TogglAPIError {
                switch error {
                case .rateLimited where retries429 < 3:
                    let delay = UInt64(pow(2.0, Double(retries429))) * 1_000_000_000
                    retries429 += 1
                    try await Task.sleep(nanoseconds: delay)
                    continue
                case .serverError where !retried5xx:
                    retried5xx = true
                    try await Task.sleep(nanoseconds: 500_000_000)
                    continue
                default:
                    throw error
                }
            }
        }
    }

    private func performRequest<T: Decodable & Sendable>(
        method: String,
        path: String,
        body: (any Encodable)?,
        token: String
    ) async throws -> T {
        guard let url = URL(string: Self.baseURL.absoluteString + path) else {
            throw TogglAPIError.unknown("Invalid URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let credentials = "\(token):api_token"
        if let data = credentials.data(using: .utf8) {
            request.setValue("Basic \(data.base64EncodedString())", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try TogglJSONCoding.encode(body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw TogglAPIError.network
        }

        guard let http = response as? HTTPURLResponse else {
            throw TogglAPIError.unknown("No HTTP response")
        }

        switch http.statusCode {
        case 200...299:
            if T.self == EmptyResponse.self, data.isEmpty {
                return EmptyResponse() as! T
            }
            if data.isEmpty, method == "DELETE" {
                return EmptyResponse() as! T
            }
            do {
                return try TogglJSONCoding.decode(T.self, from: data)
            } catch {
                throw TogglAPIError.decoding
            }
        case 401:
            throw TogglAPIError.unauthenticated
        case 404:
            throw TogglAPIError.notFound
        case 429:
            throw TogglAPIError.rateLimited
        case 500...599:
            throw TogglAPIError.serverError(http.statusCode)
        default:
            let detail = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let detail, !detail.isEmpty {
                throw TogglAPIError.unknown("HTTP \(http.statusCode): \(detail)")
            }
            throw TogglAPIError.unknown("HTTP \(http.statusCode)")
        }
    }
}
