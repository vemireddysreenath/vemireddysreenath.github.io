import Foundation

/// The most recent respiratory-rate sample HealthKit has on file. Respiratory
/// rate has no live workout stream on watchOS (platform limitation — see PRD
/// §2.1), so every place this is shown must carry a recency label rather than
/// implying a live value.
public struct RespiratoryRateSample: Sendable, Equatable {
    public var breathsPerMinute: Double
    public var date: Date

    public init(breathsPerMinute: Double, date: Date) {
        self.breathsPerMinute = breathsPerMinute
        self.date = date
    }

    /// e.g. "14 br/min · last night" — matches the PRD's example format.
    public func displayLabel(now: Date = Date(), calendar: Calendar = .current, locale: Locale = .current) -> String {
        let value = String(Int(breathsPerMinute.rounded()))
        let recency = RecencyLabelFormatter.label(for: date, now: now, calendar: calendar, locale: locale)
        return "\(value) br/min · \(recency)"
    }
}

public enum RecencyLabelFormatter {
    /// Human recency label: "just now", "12 min ago", "3h ago", "last night",
    /// "yesterday", "4 days ago", or a short date beyond a week.
    /// `now`/`calendar`/`locale` are injectable so this stays deterministic in tests.
    public static func label(for date: Date, now: Date = Date(), calendar: Calendar = .current, locale: Locale = .current) -> String {
        guard date < now else { return "just now" }
        let seconds = now.timeIntervalSince(date)

        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(Int(seconds / 60)) min ago" }

        let startOfToday = calendar.startOfDay(for: now)
        let startOfSampleDay = calendar.startOfDay(for: date)
        let dayDelta = calendar.dateComponents([.day], from: startOfSampleDay, to: startOfToday).day ?? 0

        if dayDelta <= 0 {
            return "\(Int(seconds / 3600))h ago"
        }

        if dayDelta == 1 {
            // Respiratory rate is mostly captured overnight; an evening/
            // overnight sample from the prior day reads better as
            // "last night" than "yesterday".
            let hour = calendar.component(.hour, from: date)
            return (hour >= 18 || hour < 12) ? "last night" : "yesterday"
        }

        if dayDelta < 7 {
            return "\(dayDelta) days ago"
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
