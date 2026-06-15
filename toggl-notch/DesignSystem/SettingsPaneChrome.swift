import SwiftUI

extension View {
    /// Lets the shell glass show through native scroll/list/form containers in Settings.
    func settingsPaneChrome() -> some View {
        scrollContentBackground(.hidden)
    }
}
