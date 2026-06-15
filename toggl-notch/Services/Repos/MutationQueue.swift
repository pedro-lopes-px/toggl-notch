import Foundation

/// Serializes mutations per entity key so rapid start→stop→start cannot interleave.
/// Lives on the main actor alongside the repos that use it, avoiding Sendable closure issues.
@MainActor
final class MutationQueue {
    private var locked = Set<String>()
    private var waiters: [String: [CheckedContinuation<Void, Never>]] = [:]

    func enqueue<T>(key: String, operation: () async throws -> T) async throws -> T {
        await lock(key)
        defer { unlock(key) }
        return try await operation()
    }

    private func lock(_ key: String) async {
        guard locked.contains(key) else {
            locked.insert(key)
            return
        }
        await withCheckedContinuation { continuation in
            waiters[key, default: []].append(continuation)
        }
    }

    private func unlock(_ key: String) {
        if var queue = waiters[key], !queue.isEmpty {
            let next = queue.removeFirst()
            if queue.isEmpty {
                waiters.removeValue(forKey: key)
            } else {
                waiters[key] = queue
            }
            next.resume()
        } else {
            locked.remove(key)
        }
    }
}
