import Foundation
import HealthKit
import Observation
import PulseBoardShared

/// The phone's HealthKit gateway: authorization, historical queries, and the
/// Siri/App Intents data source. Read-only — the phone never writes to
/// HealthKit; the watch is the only writer (its `WorkoutManager` owns
/// `HKLiveWorkoutBuilder`).
@MainActor
@Observable
final class HealthStore {
    private let healthStore = HKHealthStore()

    private(set) var deniedTypes: Set<HKObjectType> = []

    static let isHealthDataAvailable = HKHealthStore.isHealthDataAvailable()

    static let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    static let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
    static let basalEnergyType = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!
    static let respiratoryRateType = HKQuantityType.quantityType(forIdentifier: .respiratoryRate)!
    static let vo2MaxType = HKQuantityType.quantityType(forIdentifier: .vo2Max)!
    static let restingHeartRateType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
    static let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    static let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    static let distanceWalkingRunningType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
    static let distanceCyclingType = HKQuantityType.quantityType(forIdentifier: .distanceCycling)!
    static let workoutType = HKObjectType.workoutType()
    static let dateOfBirthType = HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!

    /// Every type in PRD §2's read list. Phase 1 doesn't display VO2 max /
    /// HRV / resting HR / step count anywhere yet, but permission for them
    /// is requested up front (as the PRD specifies) so Phase 2's Trends
    /// screen never needs a second permission prompt.
    static let allReadTypes: Set<HKObjectType> = [
        heartRateType, activeEnergyType, basalEnergyType, respiratoryRateType,
        vo2MaxType, restingHeartRateType, hrvType, stepCountType,
        distanceWalkingRunningType, distanceCyclingType, workoutType, dateOfBirthType
    ]

    func requestAuthorization() async throws {
        guard Self.isHealthDataAvailable else { return }
        try await healthStore.requestAuthorization(toShare: [], read: Self.allReadTypes)
        refreshAuthorizationStatuses()
    }

    /// `.sharingDenied` is the only status HealthKit reports for *read*-only
    /// types — `.notDetermined` and "authorized" are otherwise
    /// indistinguishable by design (Apple deliberately hides whether read
    /// access was granted), so "denied" is the one degraded state we can
    /// reliably detect and design around per PRD constraint §2.4.
    func refreshAuthorizationStatuses() {
        deniedTypes = Set(Self.allReadTypes.filter {
            healthStore.authorizationStatus(for: $0) == .sharingDenied
        })
    }

    func isDenied(_ type: HKObjectType) -> Bool {
        deniedTypes.contains(type)
    }

    // MARK: - Max heart rate

    func maxHR(overriddenBy override: Int?) -> Int {
        if let override { return override }
        if let components = try? healthStore.dateOfBirthComponents(),
           let dob = Calendar.current.date(from: components) {
            return HRZoneCalculator.maxHR(dateOfBirth: dob)
        }
        return HRZoneCalculator.estimatedMaxHR(age: 35)
    }

    // MARK: - Respiratory rate (never live — see PRD §2.1)

    func latestRespiratoryRateSample() async -> RespiratoryRateSample? {
        guard let sample = await latestQuantitySample(
            of: Self.respiratoryRateType,
            unit: HKUnit.count().unitDivided(by: .minute())
        ) else { return nil }
        return RespiratoryRateSample(breathsPerMinute: sample.value, date: sample.date)
    }

    func latestHeartRateSample() async -> (value: Double, date: Date)? {
        await latestQuantitySample(of: Self.heartRateType, unit: HKUnit.count().unitDivided(by: .minute()))
    }

    private func latestQuantitySample(of type: HKQuantityType, unit: HKUnit) async -> (value: Double, date: Date)? {
        await withCheckedContinuation { continuation in
            let sort = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: sort) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: (sample.quantity.doubleValue(for: unit), sample.endDate))
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Today's totals (Siri "calories burned today")

    func todaysActiveCalories() async -> Double {
        await sum(of: Self.activeEnergyType, unit: .kilocalorie(), start: Calendar.current.startOfDay(for: Date()), end: Date())
    }

    func todaysBasalCalories() async -> Double {
        await sum(of: Self.basalEnergyType, unit: .kilocalorie(), start: Calendar.current.startOfDay(for: Date()), end: Date())
    }

    private func sum(of type: HKQuantityType, unit: HKUnit, start: Date, end: Date) async -> Double {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, _ in
                continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Workout history

    func recentWorkouts(limit: Int = 25) async -> [HKWorkout] {
        await withCheckedContinuation { continuation in
            let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            let query = HKSampleQuery(sampleType: Self.workoutType, predicate: nil, limit: limit, sortDescriptors: sort) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            healthStore.execute(query)
        }
    }

    /// Built from `HKWorkout.statistics(for:)` — the per-quantity-type
    /// aggregates HealthKit precomputes when the workout was saved, so this
    /// needs no extra queries and can't disagree with what Apple Fitness
    /// shows for the same workout. Zone-time distribution isn't
    /// reconstructed here: that needs the raw per-second HR samples, which
    /// the *just-ended* summary already gets for free from the watch's own
    /// live `ZoneTimeAccumulator` (see `MetricsStore.lastSummary`) — history
    /// rows further back don't re-derive it.
    func summary(for workout: HKWorkout) -> WorkoutSummary {
        let hrUnit = HKUnit.count().unitDivided(by: .minute())
        let hrStats = workout.statistics(for: Self.heartRateType)
        let activeStats = workout.statistics(for: Self.activeEnergyType)
        let distanceType: HKQuantityType = workout.workoutActivityType == .cycling
            ? Self.distanceCyclingType
            : Self.distanceWalkingRunningType
        let distanceStats = workout.statistics(for: distanceType)
        let active = activeStats?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0

        return WorkoutSummary(
            workoutKind: WorkoutKind(healthKitActivityType: workout.workoutActivityType),
            startDate: workout.startDate,
            endDate: workout.endDate,
            avgHR: hrStats?.averageQuantity()?.doubleValue(for: hrUnit),
            minHR: hrStats?.minimumQuantity()?.doubleValue(for: hrUnit),
            maxHR: hrStats?.maximumQuantity()?.doubleValue(for: hrUnit),
            activeCalories: active,
            totalCalories: active,
            distanceMeters: distanceStats?.sumQuantity()?.doubleValue(for: .meter()),
            zoneDistribution: []
        )
    }
}
