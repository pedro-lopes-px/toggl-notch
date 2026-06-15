import SwiftUI

struct CalendarView: View {
    @Environment(NotchStore.self) private var store
    @State private var selectedDate = Date.now

    private var hasRunningEntry: Bool {
        store.runningEntry != nil
    }

    private var showsRunningEntry: Bool {
        guard let running = store.runningEntry else { return false }
        return Calendar.current.isDate(running.startedAt, inSameDayAs: selectedDate)
    }

    var body: some View {
        Group {
            if hasRunningEntry {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    calendarContent(now: context.date)
                }
            } else {
                calendarContent(now: .now)
            }
        }
        .task(id: selectedDate) {
            _ = await store.timeEntryRepo.entries(for: selectedDate, tagMap: store.tagRepo.tagNameToIDMap())
            await store.timeEntryRepo.prefetchWeek(containing: selectedDate, tagMap: store.tagRepo.tagNameToIDMap())
        }
    }

    private func calendarContent(now: Date) -> some View {
        let entries = store.timeEntryRepo.displayEntries(on: selectedDate, at: now)
        let runningID = showsRunningEntry ? store.runningEntry?.id : nil

        return VStack(alignment: .leading, spacing: 0) {
            RouteHeader(title: "Calendar")

            DayStrip(selectedDate: $selectedDate, now: now)
                .padding(.top, 8)

            SectionLabel(sectionTitle(now: now))
                .padding(.horizontal, NotchMetrics.panelPadding)
                .padding(.top, 8)

            DayTimeline(date: selectedDate, entries: entries, runningEntryID: runningID, now: now)
                .padding(.top, 4)
        }
    }

    private func sectionTitle(now: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE · MMM d"
        let hours = TimeFormatting.formatHours(store.timeEntryRepo.trackedSeconds(on: selectedDate, at: now))
        return "\(f.string(from: selectedDate).uppercased()) · \(hours.uppercased())"
    }

}

struct DayStrip: View {
    @Binding var selectedDate: Date
    var now: Date = .now
    @Environment(NotchStore.self) private var store

    @State private var weekOffset = 0

    private var weekDays: [Date] {
        let cal = Calendar.current
        let start = cal.date(byAdding: .weekOfYear, value: weekOffset, to: cal.startOfDay(for: .now))!
        let weekStart = cal.dateInterval(of: .weekOfYear, for: start)!.start
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
    }

    var body: some View {
        HStack(spacing: 0) {
            Button { weekOffset -= 1 } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12))
                    .foregroundStyle(NotchColors.textTertiary)
                    .frame(width: 20, height: 28)
            }
            .buttonStyle(.plain)

            ForEach(weekDays, id: \.self) { day in
                dayCell(day)
                    .frame(maxWidth: .infinity)
            }

            Button { weekOffset += 1 } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(NotchColors.textTertiary)
                    .frame(width: 20, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(weekOffset >= 0)
            .opacity(weekOffset >= 0 ? 0.4 : 1)
        }
        .padding(.horizontal, NotchMetrics.panelPadding)
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = Calendar.current.isDate(day, inSameDayAs: selectedDate)
        let isToday = Calendar.current.isDateInToday(day)
        let isFuture = day > Date.now
        let weekday = day.formatted(.dateTime.weekday(.abbreviated)).uppercased()
        let hours = store.timeEntryRepo.trackedSeconds(on: day, at: now)

        return Button {
            guard !isFuture else { return }
            selectedDate = day
        } label: {
            VStack(spacing: 2) {
                Text(weekday)
                    .font(.system(size: 11))
                    .foregroundStyle(NotchColors.textTertiary)
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(NotchColors.surfaceRaised)
                            .frame(width: 28, height: 28)
                    }
                    Text(day.formatted(.dateTime.day()))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isSelected ? NotchColors.textPrimary : NotchColors.textTertiary)
                }
                .overlay(alignment: .bottom) {
                    if isToday {
                        Circle()
                            .fill(NotchColors.accentGreen)
                            .frame(width: 4, height: 4)
                            .offset(y: 6)
                    }
                }
                Text(hours > 0 ? TimeFormatting.formatHours(hours) : "—")
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(NotchColors.textTertiary)
            }
        }
        .buttonStyle(.plain)
        .opacity(isFuture ? 0.4 : 1)
        .pointerStyle(isFuture ? .default : .link)
    }
}
