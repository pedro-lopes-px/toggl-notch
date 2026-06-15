import SwiftUI

/// Green status dot. When active, a halo pulses outward; idle is a static gray dot.
/// Offline shows a hollow ring instead of the halo.
struct ActiveDot: View {
    let active: Bool
    var offline: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var animates: Bool { active && !reduceMotion && !offline }

    var body: some View {
        ZStack {
            if offline {
                Circle()
                    .strokeBorder(NotchColors.textTertiary, lineWidth: 1)
                    .frame(width: 8, height: 8)
            } else if animates {
                Circle()
                    .fill(NotchColors.accentGreen)
                    .frame(width: 8, height: 8)
                    .scaleEffect(pulse ? 1.35 : 1.0)
                    .opacity(pulse ? 0.0 : 0.5)
            }
            Circle()
                .fill(active ? NotchColors.accentGreen : NotchColors.textTertiary)
                .frame(width: 8, height: 8)
        }
        .frame(width: 8, height: 8)
        .onAppear { if animates { pulse = true } }
        .animation(animates ? .easeOut(duration: 2).repeatForever(autoreverses: false) : nil, value: pulse)
    }
}

#Preview {
    HStack(spacing: 20) {
        ActiveDot(active: true)
        ActiveDot(active: false)
        ActiveDot(active: true, offline: true)
    }
    .padding()
    .background(.black)
}
