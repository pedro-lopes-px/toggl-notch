import SwiftUI

struct Project: Identifiable, Codable, Sendable {
    typealias ID = String

    let id: ID
    var name: String
    var color: Color
    var clientID: Int?
    var clientName: String?
    var workspaceID: Int
    var active: Bool

    static let palette: [Color] = [
        Color(red: 0.478, green: 0.549, blue: 0.941),
        Color(red: 0.788, green: 0.627, blue: 0.416),
        Color(red: 0.608, green: 0.549, blue: 0.878),
        Color(red: 0.435, green: 0.722, blue: 0.659),
        Color(red: 0.690, green: 0.471, blue: 0.549),
        Color(red: 0.541, green: 0.651, blue: 0.494), // #8AA67E
        Color(red: 0.659, green: 0.561, blue: 0.722), // #A88FB8
        Color(red: 0.788, green: 0.482, blue: 0.482), // #C97B7B
    ]

    enum CodingKeys: String, CodingKey {
        case id, name, color, clientID, clientName, workspaceID, active
    }

    init(
        id: ID,
        name: String,
        color: Color,
        clientID: Int? = nil,
        clientName: String? = nil,
        workspaceID: Int = 0,
        active: Bool = true
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.clientID = clientID
        self.clientName = clientName
        self.workspaceID = workspaceID
        self.active = active
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        clientID = try c.decodeIfPresent(Int.self, forKey: .clientID)
        clientName = try c.decodeIfPresent(String.self, forKey: .clientName)
        workspaceID = try c.decodeIfPresent(Int.self, forKey: .workspaceID) ?? 0
        active = try c.decodeIfPresent(Bool.self, forKey: .active) ?? true
        if let hex = try c.decodeIfPresent(String.self, forKey: .color) {
            color = Color(hex: hex) ?? Self.palette[0]
        } else {
            color = Self.palette[0]
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(clientID, forKey: .clientID)
        try c.encodeIfPresent(clientName, forKey: .clientName)
        try c.encode(workspaceID, forKey: .workspaceID)
        try c.encode(active, forKey: .active)
        try c.encode(color.hexString, forKey: .color)
    }
}

extension Project: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Project, rhs: Project) -> Bool { lhs.id == rhs.id }
}
