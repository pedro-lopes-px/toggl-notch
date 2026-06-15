import Foundation

enum PanelOpenTrigger: String, CaseIterable, Identifiable {
    case click
    case hover

    var id: String { rawValue }

    var label: String {
        switch self {
        case .click: "Click"
        case .hover: "Hover"
        }
    }
}
