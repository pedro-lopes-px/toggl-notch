import SwiftUI

struct SkeletonRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Circle()
                    .fill(NotchColors.surfaceRaised)
                    .frame(width: 6, height: 6)
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(NotchColors.surfaceRaised)
                        .frame(width: 140, height: 8)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(NotchColors.surfaceRaised)
                        .frame(width: 80, height: 6)
                }
                .frame(height: 29, alignment: .leading)
            }
            Spacer(minLength: 0)
        }
        .frame(height: NotchMetrics.rowHeight)
        .opacity(reduceMotion ? 0.7 : (pulse ? 1.0 : 0.5))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
