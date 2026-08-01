import Foundation

/// End-of-workout rollup shown on `SummaryView` and stored in `HistoryView`.
/// Mirrors what gets saved to HealthKit so the two never disagree.
public struct WorkoutSummary: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var workoutKind: WorkoutKind
    public var startDate: Date
    public var endDate: Date
    public var avgHR: Double?
    public var minHR: Double?
    public var maxHR: Double?
    public var activeCalories: Double
    public var totalCalories: Double
    public var distanceMeters: Double?
    public var zoneDistribution: [ZoneDuration]

    public init(
        id: UUID = UUID(),
        workoutKind: WorkoutKind,
        startDate: Date,
        endDate: Date,
        avgHR: Double?,
        minHR: Double?,
        maxHR: Double?,
        activeCalories: Double,
        totalCalories: Double,
        distanceMeters: Double?,
        zoneDistribution: [ZoneDuration]
    ) {
        self.id = id
        self.workoutKind = workoutKind
        self.startDate = startDate
        self.endDate = endDate
        self.avgHR = avgHR
        self.minHR = minHR
        self.maxHR = maxHR
        self.activeCalories = activeCalories
        self.totalCalories = totalCalories
        self.distanceMeters = distanceMeters
        self.zoneDistribution = zoneDistribution
    }

    public var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
}
