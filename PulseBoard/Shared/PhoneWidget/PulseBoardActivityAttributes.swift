import ActivityKit
import Foundation
import PulseBoardShared

// Shared by the iOS app target and the widget extension target (both need
// the concrete ContentState shape). Not part of PulseBoardShared itself,
// since ActivityKit doesn't exist on watchOS and that package is built for
// both iOS and watchOS.
struct PulseBoardActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var heartRate: Double?
        var hrMin: Double?
        var hrMax: Double?
        var activeCalories: Double
        var elapsed: TimeInterval
        var zone: HeartRateZone?
        var phase: WorkoutSessionPhase
    }

    var workoutKind: WorkoutKind
    var startDate: Date
}

extension PulseBoardActivityAttributes.ContentState {
    init(packet: MetricPacket, maxHR: Double) {
        heartRate = packet.heartRate
        hrMin = packet.hrMin
        hrMax = packet.hrMax
        activeCalories = packet.activeCalories
        elapsed = packet.elapsed
        zone = packet.heartRate.map { HRZoneCalculator.zone(forHeartRate: $0, maxHR: maxHR) }
        phase = packet.phase
    }
}
