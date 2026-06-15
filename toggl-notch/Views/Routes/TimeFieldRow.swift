import SwiftUI

struct TimeFieldRow: View {
    @Binding var startedAt: Date
    @Binding var endedAt: Date
    let isValid: Bool

    @State private var showingStartPicker = false
    @State private var showingEndPicker = false
    @State private var editingDuration = false
    @State private var durationText = ""

    private var showDate: Bool { !Calendar.current.isDateInToday(startedAt) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                if showDate {
                    Text(dateLabel)
                        .font(.system(size: 13))
                        .foregroundStyle(NotchColors.textSecondary)
                    Text("·")
                        .foregroundStyle(NotchColors.textTertiary)
                }
                timePickerButton(date: $startedAt, isPresented: $showingStartPicker)
                Text("→")
                    .font(.system(size: 13))
                    .foregroundStyle(NotchColors.textTertiary)
                timePickerButton(date: $endedAt, isPresented: $showingEndPicker)
                Text("·")
                    .foregroundStyle(NotchColors.textTertiary)
                durationButton
            }
            .font(.system(size: 13))
            .monospacedDigit()
            .foregroundStyle(isValid ? NotchColors.textSecondary : NotchColors.accentRedDim.opacity(0.8))
        }
    }

    private var dateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEE d"
        return f.string(from: startedAt)
    }

    private func timePickerButton(date: Binding<Date>, isPresented: Binding<Bool>) -> some View {
        Button(formatTime(date.wrappedValue)) {
            isPresented.wrappedValue = true
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .popover(isPresented: isPresented, arrowEdge: .bottom) {
            WheelTimePicker(date: date)
                .padding(12)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private var durationButton: some View {
        Group {
            if editingDuration {
                TextField("m", text: $durationText)
                    .textFieldStyle(.plain)
                    .frame(width: 48)
                    .onSubmit { applyDuration() }
            } else {
                Button(TimeFormatting.formatDuration(max(0, Int(endedAt.timeIntervalSince(startedAt))))) {
                    durationText = String(max(0, Int(endedAt.timeIntervalSince(startedAt))) / 60)
                    editingDuration = true
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
            }
        }
    }

    private func applyDuration() {
        if let minutes = Int(durationText) {
            endedAt = startedAt.addingTimeInterval(TimeInterval(minutes * 60))
        }
        editingDuration = false
    }
}
