import SwiftUI

/// Sizes, radii, spacing, and the shared motion curves for the notch shell.
enum NotchMetrics {
    // Stage (fixed transparent panel)
    static let stageWidth: CGFloat = 560
    static let stageHeight: CGFloat = 600

    // Shell
    static let collapsedWidth: CGFloat = 220 // fallback pill width on notch-less displays
    static let collapsedHeight: CGFloat = 36
    static let expandedWidth: CGFloat = 400
    static let maxExpandedHeight: CGFloat = 520
    static let collapsedRadius: CGFloat = 14
    static let expandedRadius: CGFloat = 24

    /// Solid black band fused with the physical notch before the surface fade begins.
    static let notchFusionSolidHeight: CGFloat = 74
    /// Height over which the black→clear transition completes (longer = smoother handoff to glass).
    static let notchFusionFadeHeight: CGFloat = 96

    /// Width of the info strip on each side of the notch when collapsed.
    /// Kept so the collapsed bar stays just under the expanded width.
    static let collapsedSideWidth: CGFloat = 104

    // Collapsed left strip — measured from dot trailing edge to notch leading edge.
    static let collapsedStripLeadingPadding: CGFloat = 16
    static let collapsedStripTrailingPadding: CGFloat = 8
    static let collapsedStripItemSpacing: CGFloat = 6
    static let statusDotSize: CGFloat = 8

    // Expanded header — leading block must stay left of the physical notch column.
    static let expandedHeaderItemSpacing: CGFloat = 8
    static let notchTitleClearance: CGFloat = 4

    /// Max width for the expanded header's leading block (dot + titles), left of the notch.
    static func expandedLeadingSectionMaxWidth(shellWidth: CGFloat, notchWidth: CGFloat) -> CGFloat {
        let notchLeadingEdge = (shellWidth - notchWidth) / 2
        return max(0, notchLeadingEdge - panelPadding - notchTitleClearance)
    }

    /// Total collapsed width: the notch plus a strip on each side for info.
    static func collapsedShellWidth(notchWidth: CGFloat) -> CGFloat {
        notchWidth + 2 * collapsedSideWidth
    }

    /// Collapsed stays notch-tied; expanded widens to fill the stage.
    static func shellWidth(notchWidth: CGFloat, expanded: Bool) -> CGFloat {
        if expanded {
            return max(stageWidth, collapsedShellWidth(notchWidth: notchWidth))
        }
        return collapsedShellWidth(notchWidth: notchWidth)
    }

    // Rhythm
    static let panelPadding: CGFloat = 16
    static let sectionGap: CGFloat = 12
    static let rowHeight: CGFloat = 40

    // Settings
    static let settingsSectionGap: CGFloat = 20
    static let settingsSectionHeaderGap: CGFloat = 8
    static let settingsRowGap: CGFloat = 10
    static let settingsRowMinHeight: CGFloat = 28
    static let settingsListRowInsets = EdgeInsets(
        top: 6,
        leading: panelPadding,
        bottom: 6,
        trailing: panelPadding
    )

    // Motion — one spring both ways so the shell never outruns its content.
    static let shellSpring = Animation.spring(duration: 0.28, bounce: 0.04)
    static let reduceMotionShell = Animation.easeOut(duration: 0.14)

    static func shellAnimation(expanded: Bool, reduceMotion: Bool) -> Animation {
        reduceMotion ? reduceMotionShell : shellSpring
    }

    /// Collapsed strip: hide quickly on open (morph carries continuity), return
    /// after the shell settles on close.
    static func collapsedOpacityAnimation(expanded: Bool, reduceMotion: Bool) -> Animation {
        if expanded {
            return reduceMotion ? .easeOut(duration: 0.08) : .easeIn(duration: 0.08)
        }
        return reduceMotion
            ? .easeOut(duration: 0.12).delay(0.04)
            : .easeOut(duration: 0.14).delay(0.05)
    }

    /// Expanded panel: appear instantly on open so matched geometry is the only
    /// header motion; fade out quickly on close.
    static func expandedOpacityAnimation(expanded: Bool, reduceMotion: Bool) -> Animation? {
        expanded ? nil : (reduceMotion ? .easeOut(duration: 0.08) : .easeIn(duration: 0.08))
    }

    /// Body sections below the morphing header — stagger only while unfolding.
    static func sectionRevealAnimation(index: Int, expanded: Bool, reduceMotion: Bool) -> Animation? {
        guard expanded else {
            return reduceMotion ? .easeOut(duration: 0.08) : .easeIn(duration: 0.08)
        }
        if reduceMotion {
            return .easeOut(duration: 0.14).delay(Double(index) * 0.025)
        }
        return .easeOut(duration: 0.16).delay(0.1 + Double(index) * 0.025)
    }

    /// The square-topped, round-bottomed shape that fuses the surface to the notch.
    static func shellShape(radius: CGFloat) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: radius,
            bottomTrailingRadius: radius,
            topTrailingRadius: 0
        )
    }

}
