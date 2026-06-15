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
        Button(label, systemImage: systemName, action: action)
            .labelStyle(.iconOnly)
            .buttonStyle(PressableButtonStyle())
            .pointerStyle(.link)
            .background {
                ZStack {
                    Circle()
                        .fill(hovering ? NotchColors.surfaceHover : NotchColors.surfaceRaised)
                }
                .frame(width: diameter, height: diameter)
            }
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundStyle(hovering ? hoverTint : NotchColors.textSecondary)
            .frame(width: diameter, height: diameter)
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.15), value: hovering)
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
