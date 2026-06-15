import SwiftUI

/// Exact color tokens for the notch utility. Dark-mode only.
/// Values are written as decimals to avoid integer-division traps.
enum NotchColors {
    // Surfaces
    /// Opaque black fused with the physical MacBook notch housing.
    static let physicalNotch = Color.black
    static let surfaceNotch = Color(red: 0.063, green: 0.063, blue: 0.071).opacity(0.62) // over the blur material
    static let surfaceRaised = Color.white.opacity(0.04)
    static let surfaceHover = Color.white.opacity(0.07)
    static let surfaceActive = Color.white.opacity(0.10)

    // Borders
    static let borderSubtle = Color.white.opacity(0.07)
    static let borderEdge = Color.white.opacity(0.12) // 1px inner top hairline

    // Text
    static let textPrimary = Color.white.opacity(0.92)
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary = Color.white.opacity(0.32)

    // Accents (muted)
    static let accentGreen = Color(red: 0.188, green: 0.820, blue: 0.345).opacity(0.85) // muted Apple green
    static let accentRedDim = Color(red: 1.0, green: 0.412, blue: 0.380).opacity(0.90) // stop hover only
}
