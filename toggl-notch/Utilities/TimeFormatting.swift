import Foundation

/// Exact time-string formatting for timers, durations, and summary hours.
///
/// Edge values:
///   formatTimer(0)    = "0:00"      formatTimer(59)   = "0:59"
///   formatTimer(3599) = "59:59"     formatTimer(3600) = "1:00:00"
///   formatTimer(6840) = "1:54:00"
///   formatDuration(1080) = "18m"    formatDuration(6840) = "1h 54m"
///   formatHours(0) = "0.0h"         formatHours(19103) ≈ "5.3h"
enum TimeFormatting {
    static func formatTimer(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        }
        return String(format: "%d:%02d", m, sec)
    }

    static func formatDuration(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        if h > 0 {
            return "\(h)h \(m)m"
        }
        return "\(m)m"
    }

    static func formatHours(_ seconds: Int) -> String {
        let hours = Double(max(0, seconds)) / 3600
        return String(format: "%.1fh", hours)
    }
}
