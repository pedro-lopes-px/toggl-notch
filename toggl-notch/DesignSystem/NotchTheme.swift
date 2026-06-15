import SwiftUI

/// Resolved appearance variant. `physicalNotch` (fusion gradient) stays black in every theme.
enum NotchTheme: Equatable {
    case light
    case dark

    init(colorScheme: ColorScheme) {
        self = colorScheme == .dark ? .dark : .light
    }

    var palette: NotchThemePalette {
        switch self {
        case .light: .light
        case .dark: .dark
        }
    }
}

struct NotchThemePalette: Equatable {
    /// Tint layered over the glass material — drives the visible shell body color.
    let shellTint: Color
    let surfaceNotch: Color
    let surfaceRaised: Color
    let surfaceHover: Color
    let surfaceActive: Color
    let borderSubtle: Color
    let borderEdge: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let accentGreen: Color
    let accentRedDim: Color
    /// Optional abstract multi-color atmosphere for the shell glass (below the fusion gradient).
    let shellAtmosphere: ShellAtmosphere?

    static let dark = NotchThemePalette(
        shellTint: Color(red: 0.063, green: 0.063, blue: 0.071).opacity(0.62),
        surfaceNotch: Color(red: 0.063, green: 0.063, blue: 0.071).opacity(0.62),
        surfaceRaised: Color.white.opacity(0.04),
        surfaceHover: Color.white.opacity(0.07),
        surfaceActive: Color.white.opacity(0.10),
        borderSubtle: Color.white.opacity(0.07),
        borderEdge: Color.white.opacity(0.12),
        textPrimary: Color.white.opacity(0.92),
        textSecondary: Color.white.opacity(0.55),
        textTertiary: Color.white.opacity(0.32),
        accentGreen: Color(red: 0.188, green: 0.820, blue: 0.345).opacity(0.85),
        accentRedDim: Color(red: 1.0, green: 0.412, blue: 0.380).opacity(0.90),
        shellAtmosphere: nil
    )

    static let light = NotchThemePalette(
        shellTint: Color.white.opacity(0.72),
        surfaceNotch: Color.white.opacity(0.68),
        surfaceRaised: Color.black.opacity(0.04),
        surfaceHover: Color.black.opacity(0.07),
        surfaceActive: Color.black.opacity(0.10),
        borderSubtle: Color.black.opacity(0.08),
        borderEdge: Color.black.opacity(0.12),
        textPrimary: Color.black.opacity(0.88),
        textSecondary: Color.black.opacity(0.55),
        textTertiary: Color.black.opacity(0.35),
        accentGreen: Color(red: 0.12, green: 0.62, blue: 0.28).opacity(0.92),
        accentRedDim: Color(red: 0.82, green: 0.24, blue: 0.20).opacity(0.92),
        shellAtmosphere: nil
    )
}

@MainActor
enum NotchThemePaletteRegistry {
    static var active: NotchThemePalette = NotchTheme.dark.palette

    static func apply(_ theme: NotchTheme) {
        active = theme.palette
    }

    static func apply(colorScheme: ColorScheme) {
        apply(NotchTheme(colorScheme: colorScheme))
    }
}
