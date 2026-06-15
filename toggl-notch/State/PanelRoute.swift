import Foundation

enum ComposerMode: Equatable, Hashable {
    case new
    case edit(TimeEntry)
    case `continue`(TimeEntry)

    var prefilledEntry: TimeEntry? {
        switch self {
        case .new: nil
        case .edit(let entry), .continue(let entry): entry
        }
    }
}

enum PanelRoute: Equatable, Hashable {
    case home
    case composer(ComposerMode)
    case calendar
    case settings(SettingsRoute)

    var title: String {
        switch self {
        case .home: "Home"
        case .composer(let mode):
            switch mode {
            case .new, .continue: "New entry"
            case .edit: "Edit entry"
            }
        case .calendar: "Calendar"
        case .settings: "Settings"
        }
    }

    var navSlot: Int? {
        switch self {
        case .home, .composer: nil
        case .calendar: 2
        case .settings: 3
        }
    }

    var settingsSection: SettingsRoute? {
        if case .settings(let section) = self { return section }
        return nil
    }
}
