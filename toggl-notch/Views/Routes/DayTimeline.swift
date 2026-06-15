import SwiftUI

private enum TimelineMetrics {
    static let startHour = 0
    static let endHour = 24
    static let defaultHourHeight: CGFloat = 48
    static let minHourHeight: CGFloat = 32
    static let maxHourHeight: CGFloat = 72
    static let hourLabelWidth: CGFloat = 40
    static let colorBarWidth: CGFloat = 4
    static let minBlockHeight: CGFloat = 32
    static let blockCornerRadius: CGFloat = 8
    static let blockInset: CGFloat = 4
}

struct DayTimeline: View {
    let date: Date
    let entries: [TimeEntry]
    var runningEntryID: String?
    var now: Date = .now

    @State private var hourHeight = TimelineMetrics.defaultHourHeight

    private var hourCount: Int { TimelineMetrics.endHour - TimelineMetrics.startHour }
    private var timelineHeight: CGFloat { CGFloat(hourCount) * hourHeight }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollViewReader { proxy in
                ScrollView {
                    timelineContent
                        .padding(.horizontal, NotchMetrics.panelPadding)
                        .padding(.bottom, 8)
                }
                .scrollIndicators(.hidden)
                .onAppear { scrollToFocus(using: proxy) }
                .onChange(of: date) { _, _ in scrollToFocus(using: proxy) }
                .onChange(of: entries.map(\.id)) { _, _ in scrollToFocus(using: proxy) }
            }

            zoomControls
                .padding(.trailing, NotchMetrics.panelPadding + 4)
                .padding(.bottom, 12)
        }
    }

    private var timelineContent: some View {
        HStack(alignment: .top, spacing: 0) {
            hourLabels
            timelineCanvas
        }
        .frame(height: timelineHeight)
    }

    private var hourLabels: some View {
        VStack(spacing: 0) {
            ForEach(TimelineMetrics.startHour..<TimelineMetrics.endHour, id: \.self) { hour in
                Text(hourLabel(hour))
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(NotchColors.textTertiary)
                    .frame(width: TimelineMetrics.hourLabelWidth, height: hourHeight, alignment: .topTrailing)
                    .padding(.trailing, 6)
                    .id("hour-\(hour)")
            }
        }
    }

    private var timelineCanvas: some View {
        let placements = TimelineLayout.placements(for: entries)

        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                gridLines

                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(NotchColors.borderSubtle)
                    .frame(width: 1, height: timelineHeight)

                if Calendar.current.isDate(date, inSameDayAs: .now) {
                    nowIndicator(in: geo.size.width)
                }

                ForEach(placements, id: \.entry.id) { placement in
                    let isRunning = placement.entry.id == runningEntryID
                    let end = isRunning ? now : placement.entry.stoppedAt
                    let blockHeight = TimelineLayout.blockHeight(
                        start: placement.entry.startedAt,
                        end: end,
                        on: date,
                        hourHeight: hourHeight
                    )
                    let y = TimelineLayout.yOffset(
                        for: placement.entry.startedAt,
                        on: date,
                        hourHeight: hourHeight
                    )
                    let columnWidth = geo.size.width / CGFloat(max(placement.columnCount, 1))
                    let x = CGFloat(placement.column) * columnWidth + TimelineMetrics.blockInset
                    let width = columnWidth - TimelineMetrics.blockInset * 2

                    if y < timelineHeight, blockHeight > 0 {
                        TimelineEventBlock(
                            entry: placement.entry,
                            height: blockHeight,
                            isRunning: isRunning,
                            now: now
                        )
                            .frame(width: max(0, width), height: blockHeight, alignment: .topLeading)
                            .offset(x: x, y: y)
                    }
                }
            }
        }
        .frame(height: timelineHeight)
        .clipped()
    }

    private var gridLines: some View {
        VStack(spacing: 0) {
            ForEach(TimelineMetrics.startHour..<TimelineMetrics.endHour, id: \.self) { _ in
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(NotchColors.borderSubtle)
                        .frame(height: 1)
                    Spacer(minLength: 0)
                }
                .frame(height: hourHeight)
            }
        }
    }

    private func nowIndicator(in width: CGFloat) -> some View {
        let y = TimelineLayout.yOffset(for: .now, on: date, hourHeight: hourHeight)
        return Group {
            if y >= 0, y <= timelineHeight {
                HStack(spacing: 0) {
                    Circle()
                        .fill(NotchColors.accentGreen)
                        .frame(width: 6, height: 6)
                    Rectangle()
                        .fill(NotchColors.accentGreen.opacity(0.7))
                        .frame(width: width, height: 1)
                }
                .offset(y: y - 3)
            }
        }
    }

    private var zoomControls: some View {
        VStack(spacing: 4) {
            zoomButton(symbol: "plus", label: "Zoom in") {
                hourHeight = min(TimelineMetrics.maxHourHeight, hourHeight + 8)
            }
            zoomButton(symbol: "minus", label: "Zoom out") {
                hourHeight = max(TimelineMetrics.minHourHeight, hourHeight - 8)
            }
        }
    }

    private func zoomButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(NotchColors.textSecondary)
                .frame(width: 24, height: 24)
                .background(NotchColors.surfaceRaised, in: .circle)
        }
        .buttonStyle(.plain)
        .help(label)
        .pointerStyle(.link)
    }

    private func hourLabel(_ hour: Int) -> String {
        String(format: "%02d:00", hour)
    }

    private func scrollToFocus(using proxy: ScrollViewProxy) {
        let anchorID: String
        if Calendar.current.isDate(date, inSameDayAs: .now) {
            anchorID = "hour-\(max(TimelineMetrics.startHour, Calendar.current.component(.hour, from: .now) - 1))"
        } else if let first = entries.min(by: { $0.startedAt < $1.startedAt }) {
            let hour = Calendar.current.component(.hour, from: first.startedAt)
            anchorID = "hour-\(max(TimelineMetrics.startHour, min(hour - 1, TimelineMetrics.endHour - 1)))"
        } else {
            anchorID = "hour-8"
        }
        proxy.scrollTo(anchorID, anchor: .top)
    }
}

private struct TimelineEventBlock: View {
    let entry: TimeEntry
    let height: CGFloat
    var isRunning: Bool = false
    var now: Date = .now

    @Environment(NotchStore.self) private var store
    @State private var hovering = false
    @State private var showEditPopover = false

    private var projectColor: Color {
        store.projectRepo.project(for: entry.projectID)?.color ?? NotchColors.textTertiary
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(projectColor.opacity(0.85))
                .frame(width: TimelineMetrics.colorBarWidth, height: height)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.description)
                    .font(.system(size: 13))
                    .foregroundStyle(NotchColors.textPrimary)
                    .lineLimit(height > 52 ? 2 : 1)

                if height > 44 {
                    Text(TimeFormatting.formatTimer(durationSeconds))
                        .font(.system(size: 11))
                        .monospacedDigit()
                        .foregroundStyle(isRunning ? NotchColors.accentGreen : NotchColors.textTertiary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(hovering ? NotchColors.surfaceHover : NotchColors.surfaceRaised, in: .rect(cornerRadius: TimelineMetrics.blockCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: TimelineMetrics.blockCornerRadius, style: .continuous)
                    .stroke(NotchColors.borderSubtle, lineWidth: hovering ? 1 : 0)
            }
        }
        .frame(height: height, alignment: .top)
        .contentShape(.rect)
        .onTapGesture {
            guard !isRunning else { return }
            showEditPopover = true
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(entry.description)
        .accessibilityHint("Edit entry")
        .popover(isPresented: $showEditPopover, arrowEdge: .top) {
            RecentEntryEditPopover(entry: entry, isPresented: $showEditPopover)
        }
        .onChange(of: showEditPopover) { _, isOpen in
            guard !isRunning else { return }
            store.isEditingRecentEntry = isOpen
        }
        .onHover { hovering = $0 }
        .pointerStyle(.link)
        .contextMenu {
            if isRunning {
                Button("Stop") { store.stopTimer() }
            } else {
                Button("Edit") { showEditPopover = true }
                Button("Continue") { store.continueEntry(entry) }
                Button("Delete") {
                    store.enqueueMutation { [store] in
                        try await store.timeEntryRepo.delete(entry)
                    }
                }
            }
        }
    }

    private var durationSeconds: Int {
        if isRunning {
            return max(0, Int(now.timeIntervalSince(entry.startedAt)))
        }
        return entry.durationSeconds
    }
}

private enum TimelineLayout {
    struct Placement {
        let entry: TimeEntry
        let column: Int
        let columnCount: Int
    }

    static func placements(for entries: [TimeEntry]) -> [Placement] {
        let sorted = entries.sorted { $0.startedAt < $1.startedAt }
        guard !sorted.isEmpty else { return [] }

        var result: [Placement] = []
        var cluster: [(TimeEntry, Int)] = []
        var active: [(TimeEntry, Int)] = []

        func flushCluster() {
            guard !cluster.isEmpty else { return }
            let total = (cluster.map(\.1).max() ?? 0) + 1
            for (entry, column) in cluster {
                result.append(Placement(entry: entry, column: column, columnCount: total))
            }
            cluster.removeAll()
        }

        for entry in sorted {
            active = active.filter { $0.0.stoppedAt > entry.startedAt }
            if active.isEmpty, !cluster.isEmpty {
                flushCluster()
            }

            let used = Set(active.map(\.1))
            var column = 0
            while used.contains(column) { column += 1 }

            active.append((entry, column))
            cluster.append((entry, column))
        }
        flushCluster()
        return result
    }

    static func yOffset(for moment: Date, on day: Date, hourHeight: CGFloat) -> CGFloat {
        let start = timelineStart(on: day)
        let end = timelineEnd(on: day)
        let clamped = min(max(moment, start), end)
        let minutes = clamped.timeIntervalSince(start) / 60
        return CGFloat(minutes) * (hourHeight / 60)
    }

    static func blockHeight(start: Date, end: Date, on day: Date, hourHeight: CGFloat) -> CGFloat {
        let dayStart = timelineStart(on: day)
        let dayEnd = timelineEnd(on: day)
        let clippedStart = max(start, dayStart)
        let clippedEnd = min(end, dayEnd)
        let minutes = max(0, clippedEnd.timeIntervalSince(clippedStart) / 60)
        guard minutes > 0 else { return 0 }
        let raw = CGFloat(minutes) * (hourHeight / 60)
        return max(raw, TimelineMetrics.minBlockHeight)
    }

    private static func timelineStart(on day: Date) -> Date {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)
        return cal.date(byAdding: .hour, value: TimelineMetrics.startHour, to: dayStart)!
    }

    private static func timelineEnd(on day: Date) -> Date {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)
        return cal.date(byAdding: .hour, value: TimelineMetrics.endHour, to: dayStart)!
    }
}
