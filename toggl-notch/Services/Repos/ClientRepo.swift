import Foundation
import Observation

@MainActor
@Observable
final class ClientRepo {
    private(set) var clients: [Client] = []
    private(set) var lastFetched: Date?
    private(set) var isLoading = false

    private let api: TogglAPIClient
    private let mutationQueue = MutationQueue()
    private var workspaceID: Int?

    private static let ttl: TimeInterval = 15 * 60

    init(api: TogglAPIClient) {
        self.api = api
    }

    func setWorkspace(_ id: Int?) {
        guard workspaceID != id else { return }
        workspaceID = id
        if let id, let cached: [Client] = DiskCache.load([Client].self, workspaceID: id, entity: "clients") {
            clients = cached
        } else {
            clients = []
        }
        lastFetched = nil
    }

    func client(for id: Int?) -> Client? {
        guard let id else { return nil }
        return clients.first { $0.id == id }
    }

    func refreshIfNeeded(force: Bool = false) async {
        guard let wid = workspaceID else { return }
        if !force, let last = lastFetched, Date.now.timeIntervalSince(last) < Self.ttl { return }
        isLoading = clients.isEmpty
        defer { isLoading = false }
        do {
            let dtos = try await api.fetchClients(workspaceID: wid)
            clients = dtos.map(TogglDTOMapper.client)
            lastFetched = .now
            DiskCache.save(clients, workspaceID: wid, entity: "clients")
        } catch {}
    }

    func projectCount(for clientID: Int, projects: [Project]) -> Int {
        projects.filter { $0.clientID == clientID }.count
    }

    func seedMock(clients: [Client]) {
        self.clients = clients
    }

    func create(name: String) async throws -> Client {
        guard let wid = workspaceID else { throw TogglAPIError.unknown("No workspace") }
        let tempID = -Int.random(in: 1...999_999)
        let optimistic = Client(id: tempID, name: name, workspaceID: wid)
        clients.append(optimistic)
        return try await mutationQueue.enqueue(key: "client") { [self] in
            do {
                let dto = try await api.createClient(workspaceID: wid, body: CreateClientBody(name: name))
                let created = TogglDTOMapper.client(from: dto)
                await MainActor.run {
                    clients.removeAll { $0.id == tempID }
                    clients.append(created)
                    DiskCache.save(clients, workspaceID: wid, entity: "clients")
                }
                return created
            } catch {
                await MainActor.run { clients.removeAll { $0.id == tempID } }
                throw error
            }
        }
    }

    func update(_ client: Client) async throws -> Client {
        guard let wid = workspaceID else { throw TogglAPIError.unknown("No workspace") }
        let snapshot = clients
        if let idx = clients.firstIndex(where: { $0.id == client.id }) {
            clients[idx] = client
        }
        return try await mutationQueue.enqueue(key: "client-\(client.id)") { [self] in
            do {
                let dto = try await api.updateClient(workspaceID: wid, clientID: client.id, body: UpdateClientBody(name: client.name))
                let updated = TogglDTOMapper.client(from: dto)
                await MainActor.run {
                    if let idx = clients.firstIndex(where: { $0.id == client.id }) {
                        clients[idx] = updated
                    }
                    DiskCache.save(clients, workspaceID: wid, entity: "clients")
                }
                return updated
            } catch {
                await MainActor.run { clients = snapshot }
                throw error
            }
        }
    }

    func delete(_ client: Client) async throws {
        guard let wid = workspaceID else { throw TogglAPIError.unknown("No workspace") }
        let snapshot = clients
        clients.removeAll { $0.id == client.id }
        try await mutationQueue.enqueue(key: "client-\(client.id)") { [self] in
            do {
                try await api.deleteClient(workspaceID: wid, clientID: client.id)
                await MainActor.run {
                    DiskCache.save(clients, workspaceID: wid, entity: "clients")
                }
            } catch {
                await MainActor.run { clients = snapshot }
                throw error
            }
        }
    }
}
