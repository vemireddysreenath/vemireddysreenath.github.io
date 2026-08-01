import Foundation

/// Elapsed workout time, shared by the watch readout, iPhone dashboard, and
/// Live Activity so they can never drift into different formats.
public enum ElapsedTimeFormatter {
    /// "12:34" under an hour, "1:02:34" at or beyond an hour.
    public static func string(from seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}

public enum CalorieFormatter {
    public static func string(fromKilocalories kilocalories: Double) -> String {
        "\(Int(kilocalories.rounded())) cal"
    }
}

/// Locale-aware distance formatting without pulling in `MeasurementFormatter`
/// (keeps the shared package's Foundation surface minimal and predictable
/// across the phone, watch, and widget extension targets).
public enum DistanceFormatter {
    public static func string(fromMeters meters: Double, usesMetric: Bool = Locale.current.usesMetricSystem) -> String {
        if usesMetric {
            let km = meters / 1000
            return km >= 1 ? String(format: "%.2f km", km) : "\(Int(meters.rounded())) m"
        } else {
            let miles = meters / 1609.344
            return String(format: "%.2f mi", miles)
        }
    }
}
