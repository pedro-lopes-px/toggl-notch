import SwiftUI

/// Layered washes that tint the shell glass below the black fusion gradient.
struct ShellAtmosphere: Equatable {
    let baseWash: Color
    let steelHighlight: Color
    let copperAccent: Color
    let bronzeDepth: Color
}

struct ShellAtmosphereLayers: View {
    let atmosphere: ShellAtmosphere

    var body: some View {
        ZStack {
            atmosphere.baseWash

            RadialGradient(
                colors: [
                    atmosphere.steelHighlight,
                    atmosphere.steelHighlight.opacity(0.45),
                    .clear,
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 300
            )

            RadialGradient(
                colors: [
                    atmosphere.steelHighlight.opacity(0.55),
                    atmosphere.steelHighlight.opacity(0.2),
                    .clear,
                ],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 240
            )

            RadialGradient(
                colors: [
                    atmosphere.copperAccent.opacity(0.65),
                    atmosphere.copperAccent.opacity(0.2),
                    .clear,
                ],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 260
            )

            RadialGradient(
                colors: [
                    atmosphere.bronzeDepth.opacity(0.55),
                    atmosphere.bronzeDepth.opacity(0.2),
                    .clear,
                ],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 220
            )

            LinearGradient(
                stops: [
                    .init(color: atmosphere.steelHighlight.opacity(0.35), location: 0),
                    .init(color: .clear, location: 0.38),
                    .init(color: atmosphere.copperAccent.opacity(0.22), location: 0.72),
                    .init(color: atmosphere.bronzeDepth.opacity(0.45), location: 1),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: atmosphere.bronzeDepth.opacity(0.35), location: 0.55),
                    .init(color: atmosphere.bronzeDepth.opacity(0.6), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
