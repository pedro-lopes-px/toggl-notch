import SwiftUI

struct SectionLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .medium))
            .kerning(0.7)
            .foregroundStyle(NotchColors.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    SectionLabel("Recent")
        .padding()
        .background(.black)
}
