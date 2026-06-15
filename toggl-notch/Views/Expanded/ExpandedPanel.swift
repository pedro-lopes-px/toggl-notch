import SwiftUI

/// The expanded command-center panel shell. Route content and NavBar live in PanelContent.
struct ExpandedPanel: View {
    var body: some View {
        PanelContent()
    }
}

#Preview {
    ExpandedPanel()
        .environment(NotchStore())
        .frame(width: 380)
        .background(NotchColors.surfaceNotch)
        .background(.black)
}
