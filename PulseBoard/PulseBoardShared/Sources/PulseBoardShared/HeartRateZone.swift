import Foundation

/// Five-zone heart rate model, expressed as a fraction of the user's max HR.
public enum HeartRateZone: Int, Codable, CaseIterable, Sendable, Comparable, Identifiable, Hashable {
    case zone1 = 1
    case zone2 = 2
    case zone3 = 3
    case zone4 = 4
    case zone5 = 5

    public var id: Int { rawValue }

    public static func < (lhs: HeartRateZone, rhs: HeartRateZone) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var displayName: String {
        switch self {
        case .zone1: return "Zone 1 · Warm Up"
        case .zone2: return "Zone 2 · Fat Burn"
        case .zone3: return "Zone 3 · Aerobic"
        case .zone4: return "Zone 4 · Anaerobic"
        case .zone5: return "Zone 5 · Max"
        }
    }

    /// Lower bound of each zone as a fraction of max HR. Upper bound is the
    /// next zone's lower bound (zone 5 is open-ended above 0.90 * maxHR).
    /// This follows the common 5-zone model used by most fitness platforms
    /// (Garmin/Polar-style 50/60/70/80/90% bands); the PRD leaves the exact
    /// cut points to the implementer.
    fileprivate static let lowerFraction: [HeartRateZone: Double] = [
        .zone1: 0.50,
        .zone2: 0.60,
        .zone3: 0.70,
        .zone4: 0.80,
        .zone5: 0.90
    ]

    var lowerFraction: Double { Self.lowerFraction[self] ?? 0 }
}

/// A zone's inclusive bpm range for a specific max HR, for display
/// (e.g. "Zone 3 · 133–152 bpm").
public struct HeartRateZoneRange: Sendable, Equatable {
    public let zone: HeartRateZone
    public let lowerBPM: Int
    /// `nil` for Zone 5, which has no upper bound.
    public let upperBPM: Int?
}

public enum HRZoneCalculator {

    /// Classic age-predicted max HR estimate (220 − age). The PRD specifies
    /// this as the default, user-overridable in Settings.
    public static func estimatedMaxHR(age: Int) -> Int {
        max(0, 220 - age)
    }

    /// Age-predicted max HR derived from a HealthKit date-of-birth sample.
    public static func maxHR(
        dateOfBirth: Date,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let age = calendar.dateComponents([.year], from: dateOfBirth, to: referenceDate).year ?? 0
        return estimatedMaxHR(age: age)
    }

    /// Which of the 5 zones a live heart rate falls into, given the user's max HR.
    /// Never crashes on degenerate input: a non-positive `maxHR` clamps to Zone 1.
    public static func zone(forHeartRate hr: Double, maxHR: Double) -> HeartRateZone {
        guard maxHR > 0, hr > 0 else { return .zone1 }
        let fraction = hr / maxHR
        var current: HeartRateZone = .zone1
        for zone in HeartRateZone.allCases.sorted() {
            if fraction >= zone.lowerFraction {
                current = zone
            }
        }
        return current
    }

    /// bpm ranges for all 5 zones at a given max HR, for display in Settings
    /// or a zone legend.
    public static func zoneRanges(maxHR: Double) -> [HeartRateZoneRange] {
        let sorted = HeartRateZone.allCases.sorted()
        return sorted.enumerated().map { index, zone in
            let lower = Int((zone.lowerFraction * maxHR).rounded())
            let upper: Int?
            if index + 1 < sorted.count {
                upper = Int((sorted[index + 1].lowerFraction * maxHR).rounded()) - 1
            } else {
                upper = nil
            }
            return HeartRateZoneRange(zone: zone, lowerBPM: lower, upperBPM: upper)
        }
    }
}
