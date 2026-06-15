import SwiftUI

/// Stable identifiers for elements that morph between the collapsed pill and the
/// expanded panel header. Shared via the environment so both layouts can claim
/// the same geometry and travel between states instead of cross-fading.
enum MorphID: String {
    case timer
    case title
}

extension EnvironmentValues {
    /// The namespace used to match morphing elements across collapsed/expanded.
    /// `nil` in isolated previews, where matching is simply skipped.
    @Entry var morphNamespace: Namespace.ID?
}

extension View {
    /// Claims shared geometry for an element that exists in both notch states.
    /// No-ops when no namespace is present (e.g. standalone previews).
    ///
    /// Exactly one copy of each id must be the source at a time. Tie `isSource`
    /// to the resting state (collapsed copies source while collapsed, expanded
    /// copies source while expanded) so the geometry morphs symmetrically in
    /// both directions instead of only on the way open.
    @ViewBuilder
    func morphMatched(
        _ id: MorphID,
        in namespace: Namespace.ID?,
        properties: MatchedGeometryProperties = .frame,
        anchor: UnitPoint = .center,
        isSource: Bool
    ) -> some View {
        if let namespace {
            matchedGeometryEffect(
                id: id.rawValue,
                in: namespace,
                properties: properties,
                anchor: anchor,
                isSource: isSource
            )
        } else {
            self
        }
    }
}
