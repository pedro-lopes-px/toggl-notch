import SwiftUI

/// iOS-style scrolling hour/minute wheels (macOS has no native wheel DatePicker).
struct WheelTimePicker: View {
    @Binding var date: Date

    @State private var hour: Int
    @State private var minute: Int

    private let rowHeight: CGFloat = 36
    private let visibleRows = 5

    init(date: Binding<Date>) {
        _date = date
        let components = Calendar.current.dateComponents([.hour, .minute], from: date.wrappedValue)
        _hour = State(initialValue: components.hour ?? 0)
        _minute = State(initialValue: components.minute ?? 0)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(NotchColors.surfaceRaised)
                .frame(height: rowHeight)
                .padding(.horizontal, 4)

            HStack(spacing: 0) {
                WheelColumn(
                    values: Self.hours,
                    selection: $hour,
                    rowHeight: rowHeight,
                    visibleRows: visibleRows
                )
                Text(":")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(NotchColors.textSecondary)
                    .frame(width: 8)
                WheelColumn(
                    values: Self.minutes,
                    selection: $minute,
                    rowHeight: rowHeight,
                    visibleRows: visibleRows
                )
            }
            .monospacedDigit()
        }
        .frame(height: rowHeight * CGFloat(visibleRows))
        .onChange(of: hour) { _, _ in applySelection() }
        .onChange(of: minute) { _, _ in applySelection() }
    }

    private static let hours = Array(0..<24)
    private static let minutes = Array(0..<60)

    private func applySelection() {
        date = Self.mergeTime(hour: hour, minute: minute, into: date)
    }

    private static func mergeTime(hour: Int, minute: Int, into base: Date) -> Date {
        var cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: base)
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        return cal.date(from: comps) ?? base
    }
}

private struct WheelColumn: View {
    let values: [Int]
    @Binding var selection: Int
    let rowHeight: CGFloat
    let visibleRows: Int

    @State private var scrollID: Int?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(values, id: \.self) { value in
                    Text(String(format: "%02d", value))
                        .font(.system(size: 22, weight: value == selection ? .semibold : .regular))
                        .foregroundStyle(value == selection ? NotchColors.textPrimary : NotchColors.textTertiary)
                        .frame(height: rowHeight)
                        .frame(maxWidth: .infinity)
                        .id(value)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrollID, anchor: .center)
        .contentMargins(.vertical, rowHeight * CGFloat(visibleRows - 1) / 2, for: .scrollContent)
        .frame(width: 56, height: rowHeight * CGFloat(visibleRows))
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.22),
                    .init(color: .black, location: 0.78),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .onAppear { scrollID = selection }
        .onChange(of: scrollID) { _, new in
            guard let new, new != selection else { return }
            selection = new
        }
        .onChange(of: selection) { _, new in
            guard scrollID != new else { return }
            scrollID = new
        }
    }
}
