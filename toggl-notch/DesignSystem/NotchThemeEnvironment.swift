import SwiftUI

private struct NotchThemePaletteKey: EnvironmentKey {
    static let defaultValue = NotchThemePalette.dark
}

extension EnvironmentValues {
    var notchThemePalette: NotchThemePalette {
        get { self[NotchThemePaletteKey.self] }
        set { self[NotchThemePaletteKey.self] = newValue }
    }
}
