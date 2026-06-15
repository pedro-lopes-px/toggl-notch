import Foundation

enum SettingsRoute: String, CaseIterable, Identifiable, Hashable {
    case general
    case projects
    case tags
    case clients

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .projects: "Projects"
        case .tags: "Tags"
        case .clients: "Clients"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .projects: "folder"
        case .tags: "tag"
        case .clients: "person.2"
        }
    }
}
