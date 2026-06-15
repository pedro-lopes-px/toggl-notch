import SwiftUI

struct TodaySummary: View {
    @Environment(NotchStore.self) private var store

    var body: some View {
        HStack(spacing: 0) {
            StatBlock(value: TimeFormatting.formatHours(store.trackedSecondsToday), label: "Tracked")
            StatBlock(value: "\(store.entryCountToday)", label: "Entries")
            StatBlock(value: "\(store.deepWorkPercent)%", label: "Deep work")
        }
    }
}

#Preview {
    TodaySummary()
        .environment(NotchStore())
        .padding()
        .frame(width: 380)
        .background(.black)
}
