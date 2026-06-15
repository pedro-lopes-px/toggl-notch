import SwiftUI

/// Color tokens for the notch utility. Light and dark palettes follow the system appearance.
/// Themeable tokens resolve from `NotchThemePaletteRegistry.active`.
/// `physicalNotch` is always solid black so the fusion gradient hides the hardware notch.
enum NotchColors {
    // Surfaces — physical notch is theme-independent
    static let physicalNotch = Color.black

    static var surfaceNotch: Color { NotchThemePaletteRegistry.active.surfaceNotch }
    static var surfaceRaised: Color { NotchThemePaletteRegistry.active.surfaceRaised }
    static var surfaceHover: Color { NotchThemePaletteRegistry.active.surfaceHover }
    static var surfaceActive: Color { NotchThemePaletteRegistry.active.surfaceActive }

    // Borders
    static var borderSubtle: Color { NotchThemePaletteRegistry.active.borderSubtle }
    static var borderEdge: Color { NotchThemePaletteRegistry.active.borderEdge }

    // Text
    static var textPrimary: Color { NotchThemePaletteRegistry.active.textPrimary }
    static var textSecondary: Color { NotchThemePaletteRegistry.active.textSecondary }
    static var textTertiary: Color { NotchThemePaletteRegistry.active.textTertiary }

    // Accents
    static var accentGreen: Color { NotchThemePaletteRegistry.active.accentGreen }
    static var accentRedDim: Color { NotchThemePaletteRegistry.active.accentRedDim }
}
