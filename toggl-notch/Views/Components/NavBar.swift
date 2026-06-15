import SwiftUI

struct NavBar: View {
    @Environment(NotchStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var slotHover: Int?

    private let rowHeight: CGFloat = 28
    private let iconPointSize: CGFloat = 13

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(NotchColors.borderSubtle)
                .frame(height: 1)

            HStack(spacing: 0) {
                navSlot(1, symbol: "house", label: "Home") { store.navigateFromNavBar(.home) }
                navSlot(2, symbol: "calendar", label: "Calendar") { store.navigateFromNavBar(.calendar) }
                navSlot(3, symbol: "gearshape.2", label: "Settings") {
                    store.navigateFromNavBar(.settings(.general))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
        }
    }

    private func isSlotActive(_ slot: Int) -> Bool {
        switch slot {
        case 1: store.route == .home
        case 2, 3: store.route.navSlot == slot
        default: false
        }
    }

    @ViewBuilder
    private func navSlot(_ slot: Int, symbol: String, label: String, action: @escaping () -> Void) -> some View {
        let isActive = isSlotActive(slot)
        let isHovering = slotHover == slot

        Button(action: action) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                HStack(spacing: isActive ? 4 : 0) {
                    Image(systemName: symbol)
                        .font(.system(size: iconPointSize, weight: .medium))
                        .foregroundStyle(glyph(isActive: isActive, isHovering: isHovering))
                        .animation(.easeOut(duration: 0.12), value: isHovering)
                        .frame(width: rowHeight, height: rowHeight)

                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(NotchColors.textPrimary)
                        .lineLimit(1)
                        .fixedSize()
                        .opacity(isActive ? 1 : 0)
                        .offset(x: isActive ? 0 : -6)
                        .blur(radius: isActive ? 0 : 2)
                        .frame(width: isActive ? nil : 0, alignment: .leading)
                        .clipped()
                }
                .padding(.trailing, isActive ? 8 : 0)
                .background {
                    Capsule()
                        .fill(background(isActive: isActive, isHovering: isHovering))
                        .animation(.easeOut(duration: 0.12), value: isHovering)
                }
                .animation(selectionAnimation, value: isActive)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .frame(height: rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .onHover { slotHover = $0 ? slot : nil }
        .help(label)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private var selectionAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.15)
            : .spring(duration: 0.32, bounce: 0.12)
    }

    private func background(isActive: Bool, isHovering: Bool) -> Color {
        if isActive { return NotchColors.surfaceRaised }
        if isHovering { return NotchColors.surfaceHover }
        return .clear
    }

    private func glyph(isActive: Bool, isHovering: Bool) -> Color {
        if isActive { return NotchColors.textPrimary }
        if isHovering { return NotchColors.textSecondary }
        return NotchColors.textTertiary
    }
}
