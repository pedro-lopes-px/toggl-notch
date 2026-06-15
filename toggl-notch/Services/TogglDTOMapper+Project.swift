import SwiftUI

extension TogglDTOMapper {
    @MainActor
    static func project(from dto: TogglProjectDTO) -> Project {
        Project(
            id: String(dto.id),
            name: dto.name,
            color: Color(hex: dto.color ?? "#7A8CF0") ?? Project.palette[0],
            clientID: dto.clientID,
            clientName: dto.clientName,
            workspaceID: dto.workspaceID,
            active: dto.active
        )
    }
}
