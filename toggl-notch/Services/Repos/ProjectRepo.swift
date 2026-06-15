import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class ProjectRepo {
    private(set) var projects: [Project] = []
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
        if let id, let cached: [Project] = DiskCache.load([Project].self, workspaceID: id, entity: "projects") {
            projects = cached
        } else {
            projects = []
        }
        lastFetched = nil
    }

    func project(for id: String?) -> Project? {
        guard let id else { return nil }
        return projects.first { $0.id == id }
    }

    func refreshIfNeeded(force: Bool = false) async {
        guard let wid = workspaceID else { return }
        if !force, let last = lastFetched, Date.now.timeIntervalSince(last) < Self.ttl { return }
        isLoading = projects.isEmpty
        defer { isLoading = false }
        do {
            let dtos = try await api.fetchProjects(workspaceID: wid)
            projects = dtos.map(TogglDTOMapper.project)
            lastFetched = .now
            DiskCache.save(projects, workspaceID: wid, entity: "projects")
        } catch {
            // stale-while-revalidate
        }
    }

    func seedMock(projects: [Project]) {
        self.projects = projects
    }

    func hoursThisWeek(for projectID: String, entries: [TimeEntry]) -> Int {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return 0 }
        return entries
            .filter { $0.projectID == projectID && $0.startedAt >= weekStart }
            .reduce(0) { $0 + $1.durationSeconds }
    }

    func create(name: String, color: Color, clientID: Int?) async throws -> Project {
        guard let wid = workspaceID else { throw TogglAPIError.unknown("No workspace") }
        let tempID = UUID().uuidString
        let optimistic = Project(id: tempID, name: name, color: color, clientID: clientID, workspaceID: wid)
        projects.append(optimistic)
        return try await mutationQueue.enqueue(key: "project") { [self] in
            do {
                let body = CreateProjectBody(name: name, color: color.hexString, clientID: clientID, active: true)
                let dto = try await api.createProject(workspaceID: wid, body: body)
                let created = TogglDTOMapper.project(from: dto)
                await MainActor.run {
                    if let idx = projects.firstIndex(where: { $0.id == tempID }) {
                        projects[idx] = created
                    }
                    DiskCache.save(projects, workspaceID: wid, entity: "projects")
                }
                return created
            } catch {
                await MainActor.run {
                    projects.removeAll { $0.id == tempID }
                }
                throw error
            }
        }
    }

    func update(_ project: Project) async throws -> Project {
        guard let wid = workspaceID, let pid = Int(project.id) else { throw TogglAPIError.unknown("Invalid project") }
        let snapshot = projects
        if let idx = projects.firstIndex(where: { $0.id == project.id }) {
            projects[idx] = project
        }
        return try await mutationQueue.enqueue(key: "project-\(project.id)") { [self] in
            do {
                let body = UpdateProjectBody(
                    name: project.name,
                    color: project.color.hexString,
                    clientID: project.clientID,
                    active: project.active
                )
                let dto = try await api.updateProject(workspaceID: wid, projectID: pid, body: body)
                let updated = TogglDTOMapper.project(from: dto)
                await MainActor.run {
                    if let idx = projects.firstIndex(where: { $0.id == project.id }) {
                        projects[idx] = updated
                    }
                    DiskCache.save(projects, workspaceID: wid, entity: "projects")
                }
                return updated
            } catch {
                await MainActor.run { projects = snapshot }
                throw error
            }
        }
    }

    func archive(_ project: Project) async throws {
        var archived = project
        archived.active = false
        try await update(archived)
        await MainActor.run {
            projects.removeAll { $0.id == project.id }
            if let wid = workspaceID {
                DiskCache.save(projects, workspaceID: wid, entity: "projects")
            }
        }
    }
}