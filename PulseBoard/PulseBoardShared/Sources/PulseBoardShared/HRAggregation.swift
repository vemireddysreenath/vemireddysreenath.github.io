import Foundation

/// Incrementally tracks min / max / average heart rate over a workout.
/// Fed one sample at a time by `WorkoutManager` on the watch (the source of
/// truth per the architecture outline); pure value type so it's trivially
/// unit-testable without HealthKit.
public struct HRRollingStats: Sendable, Equatable {
    public private(set) var min: Double?
    public private(set) var max: Double?
    public private(set) var sampleCount: Int = 0
    private var sum: Double = 0

    public init() {}

    public var average: Double? {
        sampleCount > 0 ? sum / Double(sampleCount) : nil
    }

    /// Non-positive readings are dropped as sensor noise rather than
    /// corrupting min/avg.
    public mutating func record(_ heartRate: Double) {
        guard heartRate > 0 else { return }
        min = Swift.min(min ?? heartRate, heartRate)
        max = Swift.max(max ?? heartRate, heartRate)
        sum += heartRate
        sampleCount += 1
    }
}

/// A single zone's accumulated time within a workout, in a form that's both
/// `Codable` (for `WorkoutSummary`) and directly usable as Swift Charts data.
public struct ZoneDuration: Codable, Sendable, Equatable, Identifiable {
    public var zone: HeartRateZone
    public var duration: TimeInterval

    public init(zone: HeartRateZone, duration: TimeInterval) {
        self.zone = zone
        self.duration = duration
    }

    public var id: Int { zone.rawValue }
}

/// Buckets elapsed time into HR zones as samples arrive, by attributing the
/// gap between two consecutive samples to the zone the earlier sample was in.
/// Feed samples in chronological order.
public struct ZoneTimeAccumulator: Sendable, Equatable {
    private var durations: [HeartRateZone: TimeInterval] = [:]
    private var lastSampleDate: Date?
    private var lastZone: HeartRateZone?

    public init() {}

    public mutating func record(heartRate: Double, at date: Date, maxHR: Double) {
        defer {
            lastSampleDate = date
            lastZone = HRZoneCalculator.zone(forHeartRate: heartRate, maxHR: maxHR)
        }
        guard let lastDate = lastSampleDate, let lastZone else { return }
        let delta = date.timeIntervalSince(lastDate)
        guard delta > 0 else { return }
        durations[lastZone, default: 0] += delta
    }

    public func duration(in zone: HeartRateZone) -> TimeInterval {
        durations[zone] ?? 0
    }

    public var totalDuration: TimeInterval {
        durations.values.reduce(0, +)
    }

    /// All 5 zones, in order, defaulting to 0 for zones never visited —
    /// convenient for a stable bar-chart axis in `SummaryView`.
    public var asZoneDurations: [ZoneDuration] {
        HeartRateZone.allCases.sorted().map { ZoneDuration(zone: $0, duration: duration(in: $0)) }
    }
}
