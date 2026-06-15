import SwiftUI

/// Top-center stage. Everything outside the shell is transparent and inert —
/// click-through is handled at the window level by NotchPanelController.
struct RootView: View {
    var body: some View {
        VStack(spacing: 0) {
            NotchShell()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

#Preview {
    RootView()
        .environment(NotchStore())
        .frame(width: 420, height: 560)
        .background(.gray.opacity(0.3))
}
