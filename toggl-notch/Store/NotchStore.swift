import Foundation
import Observation

/// Single source of truth for all UI state, routing, and Toggl data.
@MainActor
@Observable
final class NotchStore {
    // Shell
    var isExpanded = false
    var notchSize = CGSize(width: NotchMetrics.collapsedWidth, height: NotchMetrics.collapsedHeight)

    // Routing
    var route: PanelRoute = .home
    var routeStack: [PanelRoute] = []
    var routeDirection: RouteDirection = .push

    // Auth
    /// Mirrors keychain token presence so SwiftUI can react when the token is cleared.
    private(set) var hasStoredToken = KeychainStore.readToken() != nil
    var isAuthenticated: Bool { hasStoredToken && workspaceRepo.user != nil }
    var quotaResetAt: Date? { workspaceRepo.quotaResetAt }
    var isQuotaLimited: Bool { workspaceRepo.isInQuotaCooldown }
    var isOnboarding: Bool {
        guard hasStoredToken else { return true }
        if isQuotaLimited { return false }
        if workspaceRepo.isLoading { return false }
        return workspaceRepo.user == nil
    }

    // UI state
    var errorToast: ErrorToast?
    var isOffline = false
    var showMenuBar = true
    var launchAtLogin = false {
        didSet { syncLaunchAtLogin() }
    }
    var panelOpenTrigger: PanelOpenTrigger {
        didSet { UserDefaults.standard.set(panelOpenTrigger.rawValue, forKey: Self.panelOpenTriggerKey) }
    }
    /// Draft values for starting a timer from the home shell.
    var draftDescription = ""
    var draftProjectID: String?
    var draftTagIDs: [Int] = []

    /// True while a recent-entry edit popover is open (blocks the home header from starting a timer on Return).
    var isEditingRecentEntry = false

    // Repos (exposed for views)
    let workspaceRepo: WorkspaceRepo
    let projectRepo: ProjectRepo
    let clientRepo: ClientRepo
    let tagRepo: TagRepo
    let timeEntryRepo: TimeEntryRepo

    private let api: TogglAPIClient
    // Tasks are started/cancelled on the main actor; nonisolated(unsafe) allows cleanup in deinit.
    nonisolated(unsafe) private var pollTask: Task<Void, Never>?
    nonisolated(unsafe) private var quotaRetryTask: Task<Void, Never>?
    private var pendingMutations: [( () async throws -> Void)] = []

    /// Controller hooks (window plumbing only).
    @ObservationIgnored var onExpansionChange: ((Bool) -> Void)?
    @ObservationIgnored var onShellFrameChange: ((CGRect) -> Void)?

    private static let panelOpenTriggerKey = "panelOpenTrigger"

    init(useMockData: Bool = false) {
        if let raw = UserDefaults.standard.string(forKey: Self.panelOpenTriggerKey),
           let trigger = PanelOpenTrigger(rawValue: raw) {
            panelOpenTrigger = trigger
        } else {
            panelOpenTrigger = .click
        }

        api = TogglAPIClient()
        workspaceRepo = WorkspaceRepo(api: api)
        projectRepo = ProjectRepo(api: api)
        clientRepo = ClientRepo(api: api)
        tagRepo = TagRepo(api: api)
        timeEntryRepo = TimeEntryRepo(api: api)

        if useMockData || !hasStoredToken {
            seedMockData()
        }

        wireConnectivity()
        startPolling()
    }

    deinit {
        pollTask?.cancel()
        quotaRetryTask?.cancel()
    }

    enum RouteDirection { case push, pop }

    // MARK: - Derived

    var runningEntry: RunningEntry? { timeEntryRepo.runningEntry }

    var projects: [Project] { projectRepo.projects }

    var runningProject: Project? {
        guard let id = runningEntry?.projectID else { return nil }
        return projectRepo.project(for: id)
    }

    /// Primary label in the collapsed pill: entry description, with project name as fallback.
    var collapsedWorkTitle: String {
        guard let running = runningEntry else { return "No timer" }
        let title = running.description.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { return title }
        return runningProject?.name ?? "No timer"
    }

    var runningWorkspaceName: String? {
        guard let wid = runningEntry?.workspaceID else { return nil }
        return workspaceRepo.workspaces.first { $0.id == wid }?.name
    }

    var browsingDiffersFromRunning: Bool {
        guard let running = runningEntry, let active = workspaceRepo.activeWorkspaceID else { return false }
        return running.workspaceID != active
    }

    var entries: [TimeEntry] { timeEntryRepo.entriesToday }

    var recentEntries: [TimeEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        var seen = Set<String>()
        var result: [TimeEntry] = []

        let pool = timeEntryRepo.entriesToday + (timeEntryRepo.dayCache[dayKey(yesterday)] ?? [])

        for entry in pool.sorted(by: { $0.startedAt > $1.startedAt }) {
            let key = TimeEntry.uniqueKey(description: entry.description, projectID: entry.projectID)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(entry)
            if result.count >= 5 { break }
        }
        return result
    }

    var trackedSecondsToday: Int {
        let completed = timeEntryRepo.entriesToday.reduce(0) { $0 + $1.durationSeconds }
        let running = runningEntry.map { max(0, Int(Date.now.timeIntervalSince($0.startedAt))) } ?? 0
        return completed + running
    }

    var entryCountToday: Int {
        timeEntryRepo.entriesToday.count + (runningEntry != nil ? 1 : 0)
    }

    var deepWorkPercent: Int {
        let total = timeEntryRepo.entriesToday.reduce(0) { $0 + $1.durationSeconds }
        guard total > 0 else { return 0 }
        let deep = timeEntryRepo.entriesToday.filter(\.isDeepWork).reduce(0) { $0 + $1.durationSeconds }
        return Int((Double(deep) / Double(total) * 100).rounded())
    }

    var isLoadingHome: Bool {
        timeEntryRepo.isLoading && timeEntryRepo.entriesToday.isEmpty && runningEntry == nil
    }

    // MARK: - Bootstrap

    @discardableResult
    func bootstrap() async -> Bool {
        guard hasStoredToken else { return false }
        await workspaceRepo.bootstrap()
        if isQuotaLimited, let reset = quotaResetAt {
            scheduleQuotaRetry(until: reset)
            return false
        }
        guard workspaceRepo.user != nil else { return false }
        applyWorkspaceScope()
        let tagMap = tagRepo.tagNameToIDMap()
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.tagRepo.refreshIfNeeded(force: true) }
            group.addTask { await self.projectRepo.refreshIfNeeded(force: true) }
            group.addTask { await self.clientRepo.refreshIfNeeded(force: true) }
            group.addTask { await self.timeEntryRepo.refreshCurrentEntry(tagMap: self.tagRepo.tagNameToIDMap()) }
            group.addTask { await self.timeEntryRepo.refreshToday(force: true, tagMap: self.tagRepo.tagNameToIDMap()) }
        }
        quotaRetryTask?.cancel()
        return true
    }

    func connect(token: String) async throws {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await workspaceRepo.validateToken(trimmed)
        } catch {
            if isQuotaLimited, let reset = quotaResetAt {
                scheduleQuotaRetry(until: reset)
            }
            throw error
        }
        KeychainStore.saveToken(trimmed)
        hasStoredToken = true
        guard await bootstrap() else {
            if isQuotaLimited, let reset = quotaResetAt {
                throw TogglAPIError.quotaExceeded(resetsAt: reset)
            }
            throw TogglAPIError.unknown("Token saved, but couldn't load your account. Check your connection and try again.")
        }
    }

    func disconnect() {
        KeychainStore.deleteToken()
        hasStoredToken = false
        workspaceRepo.clear()
        seedMockData()
    }

    func applyWorkspaceScope() {
        let wid = workspaceRepo.activeWorkspaceID
        projectRepo.setWorkspace(wid)
        clientRepo.setWorkspace(wid)
        tagRepo.setWorkspace(wid)
        timeEntryRepo.setWorkspace(wid)
    }

    func switchWorkspace(_ id: Int) async {
        workspaceRepo.switchWorkspace(id)
        applyWorkspaceScope()
        await bootstrap()
    }

    // MARK: - Expansion

    func expand() {
        guard !isExpanded else { return }
        isExpanded = true
        onExpansionChange?(true)
        Task {
            await refreshOnExpand()
        }
    }

    func collapse() {
        guard isExpanded else { return }
        isExpanded = false
        onExpansionChange?(false)
        Task {
            try? await Task.sleep(for: .milliseconds(reduceMotionCollapseDelay))
            popToHome()
        }
    }

    private var reduceMotionCollapseDelay: Int {
        280 // match shell spring settle
    }

    func toggleExpanded() {
        isExpanded ? collapse() : expand()
    }

    private func refreshOnExpand() async {
        guard !isQuotaLimited else { return }
        await bootstrap()
    }

    // MARK: - Timer actions

    func stopTimer() {
        Task {
            do {
                try await timeEntryRepo.stop()
            } catch {
                showError("Couldn't stop timer", retry: { [weak self] in self?.stopTimer() })
            }
        }
    }

    func startEntry(description: String = "", projectID: String? = nil, tagIDs: [Int] = []) {
        let tagNames = tagRepo.tagNames(for: tagIDs)
        Task {
            do {
                try await timeEntryRepo.start(description: description, projectID: projectID, tagIDs: tagIDs, tagNames: tagNames)
            } catch {
                #if DEBUG
                print("[Toggl Notch] start timer failed:", error)
                #endif
                showError("Couldn't start timer", retry: { [weak self] in
                    self?.startEntry(description: description, projectID: projectID, tagIDs: tagIDs)
                })
            }
        }
    }

    func startDraftEntry() {
        startEntry(description: draftDescription, projectID: draftProjectID, tagIDs: draftTagIDs)
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            collapse()
        }
    }

    func continueEntry(_ entry: TimeEntry) {
        startEntry(description: entry.description, projectID: entry.projectID, tagIDs: entry.tagIDs)
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            collapse()
        }
    }

    private func wireConnectivity() {
        Task {
            await api.setConnectivityHandler { [weak self] isOnline in
                Task { @MainActor [weak self] in
                    self?.updateConnectivity(isOnline)
                }
            }
        }
    }

    private func updateConnectivity(_ isOnline: Bool) {
        let wasOffline = isOffline
        isOffline = !isOnline
        if wasOffline && isOnline {
            Task { await flushPendingMutations() }
        }
    }

    // MARK: - Errors & offline

    func showError(_ message: String, retry: (() -> Void)? = nil) {
        errorToast = ErrorToast(message: message, retryAction: retry)
        Task {
            try? await Task.sleep(for: .seconds(4))
            if errorToast?.message == message {
                errorToast = nil
            }
        }
    }

    func dismissError() {
        errorToast = nil
    }

    func enqueueMutation(_ operation: @escaping () async throws -> Void) {
        if isOffline {
            if pendingMutations.count < 20 {
                pendingMutations.append(operation)
            }
            showError("You're offline")
            return
        }
        Task {
            do {
                try await operation()
            } catch {
                if isOffline {
                    if pendingMutations.count < 20 { pendingMutations.append(operation) }
                    showError("You're offline")
                } else {
                    showError("Couldn't save — Retry", retry: { [weak self] in
                        self?.enqueueMutation(operation)
                    })
                }
            }
        }
    }

    private func flushPendingMutations() async {
        let queue = pendingMutations
        pendingMutations = []
        for op in queue {
            try? await op()
        }
    }

    // MARK: - Polling

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let interval = pollInterval
                try? await Task.sleep(for: .seconds(interval))
                await pollCurrentEntry()
            }
        }
    }

    private var pollInterval: TimeInterval {
        if isExpanded { return 30 }
        if runningEntry != nil { return 60 }
        return 120
    }

    private func pollCurrentEntry() async {
        guard isAuthenticated, !isQuotaLimited else { return }
        await timeEntryRepo.refreshCurrentEntry(tagMap: tagRepo.tagNameToIDMap())
    }

    private func scheduleQuotaRetry(until resetsAt: Date) {
        quotaRetryTask?.cancel()
        let delay = max(0, resetsAt.timeIntervalSinceNow)
        quotaRetryTask = Task {
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            guard !Task.isCancelled else { return }
            await retryAfterQuotaReset()
        }
    }

    private func retryAfterQuotaReset() async {
        guard hasStoredToken, isQuotaLimited else { return }
        _ = await bootstrap()
    }

    // MARK: - Mock fallback

    private func seedMockData() {
        clientRepo.seedMock(clients: MockData.clients)
        projectRepo.seedMock(projects: MockData.projects)
        timeEntryRepo.seedMock(entries: MockData.entries, running: MockData.runningEntry)
    }

    private func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}

/// Backward-compatible alias while views migrate.
typealias AppStore = NotchStore
