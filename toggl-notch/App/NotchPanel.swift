import AppKit

/// Borderless, transparent panel that floats above the menu bar.
final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true } // borderless panels need this for keyboard handling
}
