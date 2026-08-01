import Foundation
import HealthKit
import Observation
import PulseBoardShared

/// Source of truth for the active workout: owns the `HKWorkoutSession` /
/// `HKLiveWorkoutBuilder`, computes HR min/max/avg from HealthKit's own
/// live statistics (so it matches Apple Fitness by construction), buckets
/// zone time, and forwards a `MetricPacket` to the phone at ~1 Hz.
@MainActor
@Observable
final class WorkoutManager: NSObject {

    private(set) var workoutKind: WorkoutKind?
    private(set) var phase: WorkoutSessionPhase = .ended
    private(set) var currentHeartRate: Double?
    private(set) var hrMin: Double?
    private(set) var hrMax: Double?
    private(set) var hrAvg: Double?
    private(set) var elapsed: TimeInterval = 0
    private(set) var activeCalories: Double = 0
    private(set) var totalCalories: Double = 0
    private(set) var distanceMeters: Double?
    private(set) var lastSummary: WorkoutSummary?
    var lastErrorMessage: String?

    /// Age-predicted default until the phone syncs a user override via
    /// `updateApplicationContext`, or this watch's own HealthKit DOB lookup
    /// resolves — see `refreshDefaultMaxHR()`.
    private(set) var maxHR: Double = 190

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var zoneAccumulator = ZoneTimeAccumulator()
    private var elapsedTimer: Timer?
    private var startDate: Date?

    /// Elapsed time is tracked from workout-session state-change timestamps
    /// rather than a free-running app timer, so it automatically accounts
    /// for pauses and can't drift from what HealthKit itself records.
    private var accumulatedElapsed: TimeInterval = 0
    private var runningIntervalStart: Date?

    let connectivity: WatchConnectivityService

    init(connectivity: WatchConnectivityService) {
        self.connectivity = connectivity
        super.init()
        connectivity.onMaxHRContextReceived = { [weak self] maxHR in
            self?.maxHR = maxHR
        }
    }

    private static let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
    private static let energyUnit = HKUnit.kilocalorie()
    private static let distanceUnit = HKUnit.meter()

    private static let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    private static let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
    private static let basalEnergyType = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!
    private static let distanceWalkingRunningType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
    private static let distanceCyclingType = HKQuantityType.quantityType(forIdentifier: .distanceCycling)!

    static let shareTypes: Set<HKSampleType> = [
        HKObjectType.workoutType(),
        heartRateType,
        activeEnergyType,
        distanceWalkingRunningType,
        distanceCyclingType
    ]

    // Built as its own literal (rather than shareTypes.union(...)) because
    // HKCharacteristicType (date of birth) is an HKObjectType but not an
    // HKSampleType, so it can't join a Set<HKSampleType> via union.
    static let readTypes: Set<HKObjectType> = [
        HKObjectType.workoutType(),
        heartRateType,
        activeEnergyType,
        distanceWalkingRunningType,
        distanceCyclingType,
        basalEnergyType,
        HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!
    ]

    var isAuthorized: Bool {
        healthStore.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized
    }

    func requestAuthorization() async {
        do {
            try await healthStore.requestAuthorization(toShare: Self.shareTypes, read: Self.readTypes)
            refreshDefaultMaxHR()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    /// Best-effort default from this watch's own HealthKit record. A phone
    /// Settings override arrives later via `updateApplicationContext` and
    /// takes precedence (see `init`).
    func refreshDefaultMaxHR() {
        guard let components = try? healthStore.dateOfBirthComponents(),
              let dob = Calendar.current.date(from: components) else { return }
        maxHR = Double(HRZoneCalculator.maxHR(dateOfBirth: dob))
    }

    func startWorkout(kind: WorkoutKind) {
        guard session == nil else { return }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = kind.healthKitActivityType
        configuration.locationType = kind.tracksDistance ? .outdoor : .indoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)

            session.delegate = self
            builder.delegate = self

            self.session = session
            self.builder = builder
            self.workoutKind = kind
            self.phase = .running
            self.zoneAccumulator = ZoneTimeAccumulator()
            self.hrMin = nil
            self.hrMax = nil
            self.hrAvg = nil
            self.currentHeartRate = nil
            self.activeCalories = 0
            self.totalCalories = 0
            self.distanceMeters = kind.tracksDistance ? 0 : nil
            self.lastSummary = nil

            let now = Date()
            self.startDate = now
            self.accumulatedElapsed = 0
            self.runningIntervalStart = now
            session.startActivity(with: now)
            builder.beginCollection(withStart: now) { [weak self] success, error in
                guard let self, let error else { return }
                Task { @MainActor in self.lastErrorMessage = error.localizedDescription }
            }

            startElapsedTimer()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func pause() {
        session?.pause()
    }

    func resume() {
        session?.resume()
    }

    func endWorkout() {
        session?.end()
    }

    /// Dismisses the post-workout summary and resets to the start screen.
    func acknowledgeSummary() {
        lastSummary = nil
        workoutKind = nil
        session = nil
        builder = nil
    }

    private func startElapsedTimer() {
        elapsedTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        elapsedTimer = timer
    }

    private func tick() {
        elapsed = currentElapsed()
        sendPacket()
    }

    private func currentElapsed(at now: Date = Date()) -> TimeInterval {
        accumulatedElapsed + (runningIntervalStart.map { now.timeIntervalSince($0) } ?? 0)
    }

    private func sendPacket() {
        guard let workoutKind else { return }
        let packet = MetricPacket(
            timestamp: Date(),
            heartRate: currentHeartRate,
            hrMin: hrMin,
            hrMax: hrMax,
            hrAvg: hrAvg,
            activeCalories: activeCalories,
            totalCalories: totalCalories,
            elapsed: elapsed,
            distanceMeters: distanceMeters,
            workoutKind: workoutKind,
            phase: phase
        )
        connectivity.send(packet)
    }

    private func finishWorkout() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        guard let builder, let workoutKind, let startDate else { return }

        builder.endCollection(withEnd: Date()) { [weak self] _, error in
            guard let self else { return }
            if let error {
                Task { @MainActor in self.lastErrorMessage = error.localizedDescription }
            }
            builder.finishWorkout { [weak self] workout, error in
                guard let self else { return }
                Task { @MainActor in
                    if let error {
                        self.lastErrorMessage = error.localizedDescription
                    }
                    let summary = WorkoutSummary(
                        workoutKind: workoutKind,
                        startDate: startDate,
                        endDate: workout?.endDate ?? Date(),
                        avgHR: self.hrAvg,
                        minHR: self.hrMin,
                        maxHR: self.hrMax,
                        activeCalories: self.activeCalories,
                        totalCalories: self.totalCalories,
                        distanceMeters: self.distanceMeters,
                        zoneDistribution: self.zoneAccumulator.asZoneDurations
                    )
                    self.lastSummary = summary
                    self.sendPacket()
                    self.connectivity.send(summary)
                }
            }
        }
    }

    private func update(for quantityType: HKQuantityType, statistics: HKStatistics) {
        switch quantityType {
        case Self.heartRateType:
            if let value = statistics.mostRecentQuantity()?.doubleValue(for: Self.heartRateUnit) {
                currentHeartRate = value
                zoneAccumulator.record(heartRate: value, at: Date(), maxHR: maxHR)
            }
            hrMin = statistics.minimumQuantity()?.doubleValue(for: Self.heartRateUnit)
            hrMax = statistics.maximumQuantity()?.doubleValue(for: Self.heartRateUnit)
            hrAvg = statistics.averageQuantity()?.doubleValue(for: Self.heartRateUnit)

        case Self.activeEnergyType:
            let active = statistics.sumQuantity()?.doubleValue(for: Self.energyUnit) ?? activeCalories
            activeCalories = active
            totalCalories = active + estimatedBasalCalories()

        case Self.distanceWalkingRunningType, Self.distanceCyclingType:
            distanceMeters = statistics.sumQuantity()?.doubleValue(for: Self.distanceUnit)

        default:
            break
        }
    }

    /// Basal energy has no meaningful "live" workout stream, so total
    /// calories is approximated as active + (an average resting rate ×
    /// elapsed time). The rate falls back to a population-average BMR
    /// (~1,700 kcal/day) when today's HealthKit basal total isn't available
    /// yet (e.g. a brand-new watch with no history).
    private func estimatedBasalCalories() -> Double {
        let fallbackRatePerSecond = 1700.0 / 86_400.0
        return fallbackRatePerSecond * elapsed
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            switch toState {
            case .running:
                self.runningIntervalStart = date
                self.phase = .running
            case .paused:
                if let start = self.runningIntervalStart {
                    self.accumulatedElapsed += date.timeIntervalSince(start)
                }
                self.runningIntervalStart = nil
                self.elapsed = self.accumulatedElapsed
                self.phase = .paused
                self.sendPacket()
            case .ended:
                if let start = self.runningIntervalStart {
                    self.accumulatedElapsed += date.timeIntervalSince(start)
                }
                self.runningIntervalStart = nil
                self.elapsed = self.accumulatedElapsed
                self.phase = .ended
                self.finishWorkout()
            default:
                break
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in self.lastErrorMessage = error.localizedDescription }
    }
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor in
            for type in collectedTypes {
                guard let quantityType = type as? HKQuantityType,
                      let statistics = workoutBuilder.statistics(for: quantityType) else { continue }
                self.update(for: quantityType, statistics: statistics)
            }
            self.sendPacket()
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
