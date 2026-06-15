import SwiftUI

/// Up to 5 recent entries. Plain VStack — no List, no ScrollView.
struct RecentEntries: View {
    @Environment(NotchStore.self) private var store

    var body: some View {
        VStack(spacing: 2) {
            ForEach(store.recentEntries) { entry in
                EntryRow(entry: entry)
            }
        }
        .padding(.horizontal, -8)
    }
}

#Preview {
    RecentEntries()
        .environment(NotchStore())
        .padding()
        .frame(width: 380)
        .background(.black)
}
