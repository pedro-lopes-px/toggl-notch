import Foundation
import Observation

@MainActor
@Observable
final class TimeEntryRepo {
    private(set) var runningEntry: RunningEntry?
    private(set) var entriesToday: [TimeEntry] = []
    private(set) var dayCache: [String: [TimeEntry]] = [:] // yyyy-MM-dd
    private(set) var lastFetched: Date?
    private(set) var isLoading = false

    private let api: TogglAPIClient
    private let mutationQueue = MutationQueue()
    private var workspaceID: Int?

    private static let ttl: TimeInterval = 60

    init(api: TogglAPIClient) {
        self.api = api
    }

    func setWorkspace(_ id: Int?) {
        guard workspaceID != id else { return }
        workspaceID = id
        if let id, let cached: CachedEntries = DiskCache.load(CachedEntries.self, workspaceID: id, entity: "entries_today") {
            entriesToday = cached.entries
            dayCache = cached.dayCache
        } else {
            entriesToday = []
            dayCache = [:]
        }
        lastFetched = nil
    }

    struct CachedEntries: Codable {
        var entries: [TimeEntry]
        var dayCache: [String: [TimeEntry]]
    }

    func seedMock(entries: [TimeEntry], running: RunningEntry?) {
        entriesToday = entries
        runningEntry = running
    }

    // MARK: - Fetch

    func refreshCurrentEntry(tagMap: [String: Int] = [:]) async {
        do {
            if let dto = try await api.fetchCurrentEntry() {
                runningEntry = TogglDTOMapper.runningEntry(from: dto, tagNameToID: tagMap)
            } else {
                runningEntry = nil
            }
        } catch TogglAPIError.unauthenticated {
            runningEntry = nil
        } catch {
            // keep local state
        }
    }

    func refreshToday(force: Bool = false, tagMap: [String: Int] = [:]) async {
        guard let wid = workspaceID else { return }
        if !force, let last = lastFetched, Date.now.timeIntervalSince(last) < Self.ttl { return }
        isLoading = entriesToday.isEmpty
        defer { isLoading = false }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? .now

        do {
            let dtos = try await api.fetchTimeEntries(start: start, end: end)
            let mapped = dtos.compactMap { TogglDTOMapper.timeEntry(from: $0, tagNameToID: tagMap) }
            entriesToday = mapped.sorted { $0.startedAt > $1.startedAt }
            dayCache[dayKey(start)] = mapped.sorted { $0.startedAt < $1.startedAt }
            lastFetched = .now
            persistCache(workspaceID: wid)
        } catch {}
    }

    func entries(for date: Date, tagMap: [String: Int] = [:]) async -> [TimeEntry] {
        let key = dayKey(date)
        if let cached = dayCache[key] { return cached }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }

        do {
            let dtos = try await api.fetchTimeEntries(start: start, end: end)
            let mapped = dtos.compactMap { TogglDTOMapper.timeEntry(from: $0, tagNameToID: tagMap) }
                .sorted { $0.startedAt < $1.startedAt }
            dayCache[key] = mapped
            if let wid = workspaceID { persistCache(workspaceID: wid) }
            return mapped
        } catch {
            return []
        }
    }

    func prefetchWeek(containing date: Date, tagMap: [String: Int] = [:]) async {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else { return }
        let start = weekInterval.start
        let end = weekInterval.end
        do {
            let dtos = try await api.fetchTimeEntries(start: start, end: end)
            var byDay: [String: [TimeEntry]] = [:]
            for dto in dtos {
                guard let entry = TogglDTOMapper.timeEntry(from: dto, tagNameToID: tagMap) else { continue }
                let key = dayKey(entry.startedAt)
                byDay[key, default: []].append(entry)
            }
            for (key, entries) in byDay {
                dayCache[key] = entries.sorted { $0.startedAt < $1.startedAt }
            }
            if let wid = workspaceID { persistCache(workspaceID: wid) }
        } catch {}
    }

    func trackedSeconds(on date: Date) -> Int {
        let key = dayKey(date)
        return (dayCache[key] ?? []).reduce(0) { $0 + $1.durationSeconds }
    }

    func cachedEntries(on date: Date) -> [TimeEntry] {
        dayCache[dayKey(date)] ?? []
    }

    // MARK: - Mutations

    func start(
        description: String,
        projectID: String?,
        tagIDs: [Int],
        tagNames: [String],
        startedAt: Date = .now
    ) async throws {
        guard let wid = workspaceID else { throw TogglAPIError.unknown("No workspace") }
        let tempID = UUID().uuidString
        let optimistic = RunningEntry(
            id: tempID,
            workspaceID: wid,
            projectID: projectID,
            description: description,
            startedAt: startedAt,
            tagIDs: tagIDs
        )
        runningEntry = optimistic

        try await mutationQueue.enqueue(key: "time-entry") { [self] in
            do {
                let pid = projectID.flatMap(Int.init)
                let dto = try await api.startEntry(
                    workspaceID: wid,
                    description: description,
                    projectID: pid,
                    tags: tagNames
                )
                await MainActor.run {
                    runningEntry = TogglDTOMapper.runningEntry(from: dto, tagNameToID: [:])
                }
            } catch {
                await MainActor.run { runningEntry = nil }
                throw error
            }
        }
    }

    func stop() async throws {
        guard let running = runningEntry, let wid = workspaceID, let eid = Int64(running.id) else {
            throw TogglAPIError.unknown("Nothing running")
        }
        let snapshot = runningEntry
        let duration = max(0, Int(Date.now.timeIntervalSince(running.startedAt)))
        let completed = TimeEntry(
            id: running.id,
            workspaceID: wid,
            projectID: running.projectID,
            description: running.description,
            startedAt: running.startedAt,
            durationSeconds: duration,
            tagIDs: running.tagIDs
        )
        runningEntry = nil
        entriesToday.insert(completed, at: 0)
        let key = dayKey(running.startedAt)
        dayCache[key, default: []].append(completed)
        dayCache[key]?.sort { $0.startedAt < $1.startedAt }

        try await mutationQueue.enqueue(key: "time-entry") { [self] in
            do {
                let dto = try await api.stopEntry(workspaceID: wid, entryID: eid)
                await MainActor.run {
                    if let entry = TogglDTOMapper.timeEntry(from: dto) {
                        if let idx = entriesToday.firstIndex(where: { $0.id == running.id }) {
                            entriesToday[idx] = entry
                        }
                        if var day = dayCache[key] {
                            if let idx = day.firstIndex(where: { $0.id == running.id }) {
                                day[idx] = entry
                            }
                            dayCache[key] = day
                        }
                    }
                    if let wid = workspaceID { persistCache(workspaceID: wid) }
                }
            } catch {
                await MainActor.run {
                    runningEntry = snapshot
                    entriesToday.removeAll { $0.id == running.id }
                    dayCache[key]?.removeAll { $0.id == running.id }
                }
                throw error
            }
        }
    }

    func update(_ entry: TimeEntry, tagNames: [String]) async throws -> TimeEntry {
        guard let wid = workspaceID, let eid = Int64(entry.id) else { throw TogglAPIError.unknown("Invalid entry") }
        let snapshotToday = entriesToday
        let snapshotDay = dayCache
        replaceEntry(entry)

        let body = UpdateEntryBody(
            description: entry.description,
            projectID: entry.projectID.flatMap(Int.init),
            tags: tagNames,
            start: entry.startedAt,
            duration: entry.durationSeconds
        )

        return try await mutationQueue.enqueue(key: "time-entry-\(entry.id)") { [self] in
            do {
                let dto = try await api.updateEntry(workspaceID: wid, entryID: eid, body: body)
                guard let updated = TogglDTOMapper.timeEntry(from: dto) else {
                    throw TogglAPIError.decoding
                }
                await MainActor.run {
                    replaceEntry(updated)
                    if let wid = workspaceID { persistCache(workspaceID: wid) }
                }
                return updated
            } catch {
                await MainActor.run {
                    entriesToday = snapshotToday
                    dayCache = snapshotDay
                }
                throw error
            }
        }
    }

    func delete(_ entry: TimeEntry) async throws {
        guard let wid = workspaceID, let eid = Int64(entry.id) else { throw TogglAPIError.unknown("Invalid entry") }
        let snapshotToday = entriesToday
        let snapshotDay = dayCache
        entriesToday.removeAll { $0.id == entry.id }
        let key = dayKey(entry.startedAt)
        dayCache[key]?.removeAll { $0.id == entry.id }

        try await mutationQueue.enqueue(key: "time-entry-\(entry.id)") { [self] in
            do {
                try await api.deleteEntry(workspaceID: wid, entryID: eid)
                await MainActor.run {
                    if let wid = workspaceID { persistCache(workspaceID: wid) }
                }
            } catch {
                await MainActor.run {
                    entriesToday = snapshotToday
                    dayCache = snapshotDay
                }
                throw error
            }
        }
    }

    // MARK: - Helpers

    private func replaceEntry(_ entry: TimeEntry) {
        if let idx = entriesToday.firstIndex(where: { $0.id == entry.id }) {
            entriesToday[idx] = entry
        }
        let key = dayKey(entry.startedAt)
        if var day = dayCache[key] {
            if let idx = day.firstIndex(where: { $0.id == entry.id }) {
                day[idx] = entry
            } else {
                day.append(entry)
            }
            dayCache[key] = day.sorted { $0.startedAt < $1.startedAt }
        }
    }

    private func persistCache(workspaceID: Int) {
        DiskCache.save(CachedEntries(entries: entriesToday, dayCache: dayCache), workspaceID: workspaceID, entity: "entries_today")
    }

    private func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: date)
    }
}
