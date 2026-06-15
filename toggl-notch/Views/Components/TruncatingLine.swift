import SwiftUI

/// Single-line text that truncates with an ellipsis inside a bounded width.
/// Morph attaches to the layout slot, not the `Text`, so truncation and
/// matched geometry do not fight each other.
struct TruncatingLine: View {
    let text: String
    var font: Font
    var color: Color
    var morphID: MorphID?
    var morphNamespace: Namespace.ID?
    var morphIsSource: Bool = false

    var body: some View {
        if let morphID, let morphNamespace {
            layoutSlot
                .morphMatched(
                    morphID,
                    in: morphNamespace,
                    properties: .position,
                    anchor: .leading,
                    isSource: morphIsSource
                )
        } else {
            layoutSlot
        }
    }

    private var layoutSlot: some View {
        HStack(spacing: 0) {
            Text(text)
                .font(font)
                .foregroundStyle(color)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(-1)
    }
}
