import Foundation

enum DiskCache {
    private static var baseURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("TogglNotch/cache", isDirectory: true)
    }

    static func url(workspaceID: Int, entity: String) -> URL {
        baseURL
            .appendingPathComponent(String(workspaceID), isDirectory: true)
            .appendingPathComponent("\(entity).json")
    }

    static func load<T: Decodable>(_ type: T.Type, workspaceID: Int, entity: String) -> T? {
        let fileURL = url(workspaceID: workspaceID, entity: entity)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func save<T: Encodable>(_ value: T, workspaceID: Int, entity: String) {
        let fileURL = url(workspaceID: workspaceID, entity: entity)
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func clear(workspaceID: Int) {
        let dir = baseURL.appendingPathComponent(String(workspaceID), isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
    }
}
