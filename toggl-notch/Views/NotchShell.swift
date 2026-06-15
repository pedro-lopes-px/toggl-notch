import SwiftUI

/// The single morphing surface: a pill that unfolds into the command-center panel.
/// The OS window never resizes — all motion happens here, inside the fixed stage.
struct NotchShell: View {
    @Environment(NotchStore.self) private var store
    @Environment(\.notchThemePalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var morph

    private var expanded: Bool { store.isExpanded }
    private var radius: CGFloat { expanded ? NotchMetrics.expandedRadius : NotchMetrics.collapsedRadius }
    private var shellWidth: CGFloat {
        NotchMetrics.shellWidth(notchWidth: store.notchSize.width, expanded: expanded)
    }
    private var shape: UnevenRoundedRectangle { NotchMetrics.shellShape(radius: radius) }
    private var shellAnimation: Animation {
        NotchMetrics.shellAnimation(expanded: expanded, reduceMotion: reduceMotion)
    }
    /// Always a concrete height so the spring can interpolate without nil/intrinsic
    /// hand-offs that produce non-finite frames mid-transition.
    private var shellHeight: CGFloat {
        expanded ? NotchMetrics.maxExpandedHeight : max(store.notchSize.height, 1)
    }

    var body: some View {
        ZStack(alignment: .top) {
            surface(palette: palette)
            content
        }
        .frame(width: shellWidth, height: shellHeight)
        .clipShape(shape)
        .animation(shellAnimation, value: expanded)
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { rect in
            store.onShellFrameChange?(rect)
        }
    }

    /// Both layouts stay mounted so matched geometry can bridge the states without
    /// a separate insert/remove transition fighting the shell spring.
    private var content: some View {
        ZStack(alignment: .top) {
            CollapsedPill()
                .opacity(expanded ? 0 : 1)
                .allowsHitTesting(!expanded)
                .animation(
                    NotchMetrics.collapsedOpacityAnimation(expanded: expanded, reduceMotion: reduceMotion),
                    value: expanded
                )

            ExpandedPanel()
                .opacity(expanded ? 1 : 0)
                .allowsHitTesting(expanded)
                .animation(
                    NotchMetrics.expandedOpacityAnimation(expanded: expanded, reduceMotion: reduceMotion),
                    value: expanded
                )
        }
        .frame(width: shellWidth, height: shellHeight, alignment: .top)
        .environment(\.morphNamespace, morph)
    }

    /// One surface for both states. At collapsed height the fusion gradient is
    /// entirely solid black; glass is revealed only as the clip grows downward.
    private func surface(palette: NotchThemePalette) -> some View {
        expandedSurface(palette: palette)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func expandedSurface(palette: NotchThemePalette) -> some View {
        Rectangle()
            .fill(.clear)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { glassMaterial(palette: palette) }
            .overlay { notchFusionGradient }
            .mask(shape)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private func glassMaterial(palette: NotchThemePalette) -> some View {
        ZStack {
            if #available(macOS 26.0, *) {
                Rectangle()
                    .fill(.clear)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .glassEffect(.regular, in: shape)
            } else {
                VisualEffectView()
            }

            palette.shellTint

            if let atmosphere = palette.shellAtmosphere {
                ShellAtmosphereLayers(atmosphere: atmosphere)
            }
        }
    }

    /// Black band through 74pt, then an ease-out fade to transparent that reveals the glass.
    /// When the shell is shorter than the solid band, the gradient stays fully opaque black.
    private var notchFusionGradient: some View {
        GeometryReader { geo in
            let height = max(geo.size.height, 1)
            let solidStop = min(NotchMetrics.notchFusionSolidHeight / height, 1)
            let fadeEnd = min(
                (NotchMetrics.notchFusionSolidHeight + NotchMetrics.notchFusionFadeHeight) / height,
                1
            )

            if fadeEnd <= solidStop {
                LinearGradient(
                    stops: [
                        .init(color: NotchColors.physicalNotch, location: 0),
                        .init(color: NotchColors.physicalNotch, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                let fadeSpan = fadeEnd - solidStop

                LinearGradient(
                    stops: [
                        .init(color: NotchColors.physicalNotch, location: 0),
                        .init(color: NotchColors.physicalNotch, location: solidStop),
                        .init(color: NotchColors.physicalNotch.opacity(0.72), location: solidStop + fadeSpan * 0.20),
                        .init(color: NotchColors.physicalNotch.opacity(0.42), location: solidStop + fadeSpan * 0.45),
                        .init(color: NotchColors.physicalNotch.opacity(0.16), location: solidStop + fadeSpan * 0.70),
                        .init(color: NotchColors.physicalNotch.opacity(0.04), location: solidStop + fadeSpan * 0.90),
                        .init(color: .clear, location: fadeEnd),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    NotchShell()
        .environment(NotchStore())
        .frame(width: 420, height: 560, alignment: .top)
        .background(.gray)
}
