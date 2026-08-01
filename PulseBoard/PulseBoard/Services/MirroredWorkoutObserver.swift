import Foundation
import Observation
import PulseBoardShared

/// Best-effort support for PRD F2 ("mirror a workout started from Apple's
/// native Workout app instead"), explicitly the lowest-priority MVP item
/// ("nice-to-have... if time allows"). There is no live HealthKit stream for
/// a workout this app didn't start, so detection is a heuristic — a very
/// recent heart-rate sample implies the watch is actively recording — and,
/// once mirroring, this polls rather than streams. Latency is materially
/// higher than the watch-sourced pipeline; every view showing this data
/// must label it as mirrored.
@MainActor
@Observable
final class MirroredWorkoutObserver {
    private(set) var recentActivityDetected = false
    private(set) var isMirroring = false
    private(set) var currentHeartRate: Double?
    private(set) var elapsed: TimeInterval = 0
    private(set) var activeCaloriesSinceStart: Double = 0

    private let healthStore: HealthStore
    private var detectionTask: Task<Void, Never>?
    private var mirrorTask: Task<Void, Never>?
    private var mirrorStartDate: Date?
    private var caloriesAtMirrorStart: Double = 0

    private let recencyWindow: TimeInterval = 90
    private let detectionIntervalNanoseconds: UInt64 = 5_000_000_000
    private let pollIntervalNanoseconds: UInt64 = 3_000_000_000

    init(healthStore: HealthStore) {
        self.healthStore = healthStore
    }

    /// Call when the dashboard is idle (no watch-sourced workout active).
    func startWatchingForActivity() {
        guard detectionTask == nil else { return }
        detectionTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                if self.isMirroring {
                    try? await Task.sleep(nanoseconds: self.detectionIntervalNanoseconds)
                    continue
                }
                if let sample = await self.healthStore.latestHeartRateSample(),
                   Date().timeIntervalSince(sample.date) < self.recencyWindow {
                    self.recentActivityDetected = true
                } else {
                    self.recentActivityDetected = false
                }
                try? await Task.sleep(nanoseconds: self.detectionIntervalNanoseconds)
            }
        }
    }

    func stopWatchingForActivity() {
        detectionTask?.cancel()
        detectionTask = nil
    }

    func startMirroring() async {
        isMirroring = true
        recentActivityDetected = false
        mirrorStartDate = Date()
        caloriesAtMirrorStart = await healthStore.todaysActiveCalories()

        mirrorTask?.cancel()
        mirrorTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                if let sample = await self.healthStore.latestHeartRateSample() {
                    self.currentHeartRate = sample.value
                }
                let todaysActive = await self.healthStore.todaysActiveCalories()
                self.activeCaloriesSinceStart = max(0, todaysActive - self.caloriesAtMirrorStart)
                if let start = self.mirrorStartDate {
                    self.elapsed = Date().timeIntervalSince(start)
                }
                try? await Task.sleep(nanoseconds: self.pollIntervalNanoseconds)
            }
        }
    }

    func stopMirroring() {
        mirrorTask?.cancel()
        mirrorTask = nil
        isMirroring = false
        currentHeartRate = nil
        elapsed = 0
        activeCaloriesSinceStart = 0
        mirrorStartDate = nil
    }
}
