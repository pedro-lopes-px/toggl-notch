import SwiftUI

/// Top-center stage. Everything outside the shell is transparent and inert —
/// click-through is handled at the window level by NotchPanelController.
struct RootView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var theme: NotchTheme { NotchTheme(colorScheme: colorScheme) }

    var body: some View {
        VStack(spacing: 0) {
            NotchShell()
                .id(colorScheme)
            Spacer(minLength: 0)
        }
        .environment(\.notchThemePalette, theme.palette)
        .onAppear { NotchThemePaletteRegistry.apply(colorScheme: colorScheme) }
        .onChange(of: colorScheme) { _, newScheme in
            NotchThemePaletteRegistry.apply(colorScheme: newScheme)
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
