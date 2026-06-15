import SwiftUI

struct ActionButton: View {
    let systemName: String
    let title: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemName)
                    .font(.system(size: 16))
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 13))
                    .contentTransition(.opacity)
                Spacer(minLength: 0)
            }
            .foregroundStyle(hovering ? NotchColors.textPrimary : NotchColors.textSecondary)
            .padding(.horizontal, 10)
            .frame(height: 36)
            .frame(maxWidth: .infinity)
            .background(hovering ? NotchColors.surfaceHover : .clear, in: .rect(cornerRadius: 10))
        }
        .buttonStyle(PressableButtonStyle())
        .pointerStyle(.link)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

#Preview {
    VStack(spacing: 6) {
        ActionButton(systemName: "play.fill", title: "Start New Entry") {}
        ActionButton(systemName: "arrow.left.arrow.right", title: "Switch Project") {}
    }
    .padding()
    .frame(width: 380)
    .background(.black)
}
