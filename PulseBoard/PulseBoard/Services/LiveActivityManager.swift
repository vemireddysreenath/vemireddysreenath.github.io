import Foundation
import ActivityKit
import Observation
import PulseBoardShared

/// Starts, updates, and ends the Dynamic Island / Lock Screen Live Activity
/// (PRD F4) as workouts start, run, and end. Updates are throttled to ~1 Hz
/// per PRD §2.3 — the same cadence the watch already sends at, so this is
/// mostly a pass-through with a floor rather than an independent timer.
@MainActor
@Observable
final class LiveActivityManager {
    private var currentActivity: Activity<PulseBoardActivityAttributes>?
    private var lastUpdateDate: Date?
    private let minimumUpdateInterval: TimeInterval = 1.0

    func handle(packet: MetricPacket, maxHR: Double) {
        switch packet.phase {
        case .running, .paused:
            if currentActivity == nil {
                start(with: packet, maxHR: maxHR)
            } else {
                update(with: packet, maxHR: maxHR)
            }
        case .ended:
            let activity = currentActivity
            let state = PulseBoardActivityAttributes.ContentState(packet: packet, maxHR: maxHR)
            Task { await Self.end(activity, finalState: state) }
            currentActivity = nil
            lastUpdateDate = nil
        }
    }

    private func start(with packet: MetricPacket, maxHR: Double) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard currentActivity == nil else { return }

        let attributes = PulseBoardActivityAttributes(
            workoutKind: packet.workoutKind,
            startDate: Date().addingTimeInterval(-packet.elapsed)
        )
        let state = PulseBoardActivityAttributes.ContentState(packet: packet, maxHR: maxHR)

        do {
            currentActivity = try Activity<PulseBoardActivityAttributes>.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil)
            )
            lastUpdateDate = Date()
        } catch {
            assertionFailure("Failed to start Live Activity: \(error)")
        }
    }

    private func update(with packet: MetricPacket, maxHR: Double) {
        guard let currentActivity else { return }
        let now = Date()
        if let lastUpdateDate, now.timeIntervalSince(lastUpdateDate) < minimumUpdateInterval {
            return
        }
        lastUpdateDate = now
        let state = PulseBoardActivityAttributes.ContentState(packet: packet, maxHR: maxHR)
        Task { await currentActivity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    private static func end(_ activity: Activity<PulseBoardActivityAttributes>?, finalState: PulseBoardActivityAttributes.ContentState) async {
        guard let activity else { return }
        await activity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .after(Date.now.addingTimeInterval(10))
        )
    }
}
