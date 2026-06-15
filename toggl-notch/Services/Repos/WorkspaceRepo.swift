import Foundation
import Observation

@MainActor
@Observable
final class WorkspaceRepo {
    private(set) var workspaces: [Workspace] = []
    private(set) var user: TogglUser?
    private(set) var activeWorkspaceID: Int?
    private(set) var isLoading = false
    private(set) var quotaResetAt: Date?
    /// Stays true from the first quota error until bootstrap succeeds again.
    private(set) var isInQuotaCooldown = false

    private let api: TogglAPIClient

    init(api: TogglAPIClient) {
        self.api = api
    }

    var activeWorkspace: Workspace? {
        guard let id = activeWorkspaceID else { return nil }
        return workspaces.first { $0.id == id }
    }

    func bootstrap() async {
        isLoading = workspaces.isEmpty
        defer { isLoading = false }
        do {
            let me = try await api.fetchMe()
            user = me
            let fetched = try await api.fetchWorkspaces()
            workspaces = fetched
            if activeWorkspaceID == nil {
                activeWorkspaceID = me.defaultWorkspaceID ?? fetched.first?.id
            }
            quotaResetAt = nil
            isInQuotaCooldown = false
        } catch TogglAPIError.unauthenticated {
            user = nil
            workspaces = []
            activeWorkspaceID = nil
            quotaResetAt = nil
            isInQuotaCooldown = false
        } catch TogglAPIError.quotaExceeded(let resetsAt) {
            quotaResetAt = resetsAt
            isInQuotaCooldown = true
        } catch {
            // Keep cached state on transient errors
        }
    }

    func switchWorkspace(_ id: Int) {
        guard workspaces.contains(where: { $0.id == id }) else { return }
        activeWorkspaceID = id
    }

    func validateToken(_ token: String) async throws {
        let tempAPI = TogglAPIClient(tokenProvider: { token })
        do {
            _ = try await tempAPI.fetchMe()
            quotaResetAt = nil
            isInQuotaCooldown = false
        } catch {
            if case TogglAPIError.quotaExceeded(let resetsAt) = error {
                quotaResetAt = resetsAt
                isInQuotaCooldown = true
            }
            throw error
        }
    }

    func clear() {
        user = nil
        workspaces = []
        activeWorkspaceID = nil
        quotaResetAt = nil
        isInQuotaCooldown = false
    }
}
