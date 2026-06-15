import SwiftUI

/// A circular icon button used for the header Stop / Play controls.
struct CircularIconButton: View {
    let systemName: String
    let label: String
    let hoverTint: Color
    var diameter: CGFloat = 28
    var iconSize: CGFloat = 11
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(hovering ? NotchColors.surfaceHover : NotchColors.surfaceRaised)
                Image(systemName: systemName)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(hovering ? hoverTint : NotchColors.textSecondary)
            }
            .frame(width: diameter, height: diameter)
        }
        .buttonStyle(PressableButtonStyle())
        .pointerStyle(.link)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .accessibilityLabel(label)
    }
}

#Preview {
    HStack(spacing: 12) {
        CircularIconButton(systemName: "stop.fill", label: "Stop timer", hoverTint: NotchColors.accentRedDim) {}
        CircularIconButton(systemName: "play.fill", label: "Start timer", hoverTint: NotchColors.accentGreen) {}
    }
    .padding()
    .background(.black)
}
