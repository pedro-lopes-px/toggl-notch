import Foundation
import Observation

@MainActor
@Observable
final class TagRepo {
    private(set) var tags: [Tag] = []
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
        if let id, let cached: [Tag] = DiskCache.load([Tag].self, workspaceID: id, entity: "tags") {
            tags = cached
        } else {
            tags = []
        }
        lastFetched = nil
    }

    func tag(for id: Int) -> Tag? {
        tags.first { $0.id == id }
    }

    func tagNames(for ids: [Int]) -> [String] {
        ids.compactMap { tag(for: $0)?.name }
    }

    func tagNameToIDMap() -> [String: Int] {
        Dictionary(uniqueKeysWithValues: tags.map { ($0.name, $0.id) })
    }

    func refreshIfNeeded(force: Bool = false) async {
        guard let wid = workspaceID else { return }
        if !force, let last = lastFetched, Date.now.timeIntervalSince(last) < Self.ttl { return }
        isLoading = tags.isEmpty
        defer { isLoading = false }
        do {
            let dtos = try await api.fetchTags(workspaceID: wid)
            tags = dtos.map(TogglDTOMapper.tag)
            lastFetched = .now
            DiskCache.save(tags, workspaceID: wid, entity: "tags")
        } catch {}
    }

    func usageCountThisMonth(tagID: Int, entries: [TimeEntry]) -> Int {
        let calendar = Calendar.current
        guard let monthStart = calendar.dateInterval(of: .month, for: .now)?.start else { return 0 }
        return entries.filter { $0.startedAt >= monthStart && $0.tagIDs.contains(tagID) }.count
    }

    func create(name: String) async throws -> Tag {
        guard let wid = workspaceID else { throw TogglAPIError.unknown("No workspace") }
        let tempID = -Int.random(in: 1...999_999)
        let optimistic = Tag(id: tempID, name: name, workspaceID: wid)
        tags.append(optimistic)
        return try await mutationQueue.enqueue(key: "tag") { [self] in
            do {
                let dto = try await api.createTag(workspaceID: wid, body: CreateTagBody(name: name))
                let created = TogglDTOMapper.tag(from: dto)
                await MainActor.run {
                    tags.removeAll { $0.id == tempID }
                    tags.append(created)
                    DiskCache.save(tags, workspaceID: wid, entity: "tags")
                }
                return created
            } catch {
                await MainActor.run { tags.removeAll { $0.id == tempID } }
                throw error
            }
        }
    }

    func update(_ tag: Tag) async throws -> Tag {
        guard let wid = workspaceID else { throw TogglAPIError.unknown("No workspace") }
        let snapshot = tags
        if let idx = tags.firstIndex(where: { $0.id == tag.id }) {
            tags[idx] = tag
        }
        return try await mutationQueue.enqueue(key: "tag-\(tag.id)") { [self] in
            do {
                let dto = try await api.updateTag(workspaceID: wid, tagID: tag.id, body: UpdateTagBody(name: tag.name))
                let updated = TogglDTOMapper.tag(from: dto)
                await MainActor.run {
                    if let idx = tags.firstIndex(where: { $0.id == tag.id }) {
                        tags[idx] = updated
                    }
                    DiskCache.save(tags, workspaceID: wid, entity: "tags")
                }
                return updated
            } catch {
                await MainActor.run { tags = snapshot }
                throw error
            }
        }
    }

    func delete(_ tag: Tag) async throws {
        guard let wid = workspaceID else { throw TogglAPIError.unknown("No workspace") }
        let snapshot = tags
        tags.removeAll { $0.id == tag.id }
        try await mutationQueue.enqueue(key: "tag-\(tag.id)") { [self] in
            do {
                try await api.deleteTag(workspaceID: wid, tagID: tag.id)
                await MainActor.run {
                    DiskCache.save(tags, workspaceID: wid, entity: "tags")
                }
            } catch {
                await MainActor.run { tags = snapshot }
                throw error
            }
        }
    }
}
