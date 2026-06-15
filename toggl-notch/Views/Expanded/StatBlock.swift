import SwiftUI

struct StatBlock: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(NotchColors.textPrimary)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(NotchColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    HStack(spacing: 0) {
        StatBlock(value: "5.3h", label: "Tracked")
        StatBlock(value: "7", label: "Entries")
        StatBlock(value: "84%", label: "Deep work")
    }
    .padding()
    .frame(width: 380)
    .background(.black)
}
