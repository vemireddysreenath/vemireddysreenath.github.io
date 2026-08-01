import Foundation

/// Lifecycle state of the watch-side workout session, carried in every
/// `MetricPacket` so the phone can render "reconnecting…" / paused states
/// without guessing from silence alone.
public enum WorkoutSessionPhase: String, Codable, Sendable, Hashable {
    case running
    case paused
    case ended
}

/// The single message type streamed from watch to phone at ~1 Hz via
/// `WatchConnectivity`, per the architecture outline in the PRD. All
/// aggregate HR stats (min/max/avg) are computed on the watch — the phone
/// only displays them.
public struct MetricPacket: Codable, Sendable, Equatable {
    public var timestamp: Date
    /// Current live heart rate in bpm. `nil` if no HR signal yet (e.g. sensor
    /// still acquiring a lock at workout start).
    public var heartRate: Double?
    public var hrMin: Double?
    public var hrMax: Double?
    public var hrAvg: Double?
    public var activeCalories: Double
    public var totalCalories: Double
    public var elapsed: TimeInterval
    /// Present only for workout kinds where `WorkoutKind.tracksDistance` is true.
    public var distanceMeters: Double?
    public var workoutKind: WorkoutKind
    public var phase: WorkoutSessionPhase

    public init(
        timestamp: Date,
        heartRate: Double?,
        hrMin: Double?,
        hrMax: Double?,
        hrAvg: Double?,
        activeCalories: Double,
        totalCalories: Double,
        elapsed: TimeInterval,
        distanceMeters: Double?,
        workoutKind: WorkoutKind,
        phase: WorkoutSessionPhase
    ) {
        self.timestamp = timestamp
        self.heartRate = heartRate
        self.hrMin = hrMin
        self.hrMax = hrMax
        self.hrAvg = hrAvg
        self.activeCalories = activeCalories
        self.totalCalories = totalCalories
        self.elapsed = elapsed
        self.distanceMeters = distanceMeters
        self.workoutKind = workoutKind
        self.phase = phase
    }
}

public enum ConnectivityPayloadError: Error, Sendable, Equatable {
    case missingPayload
}

extension MetricPacket {
    /// Key used in the `[String: Any]` dictionaries passed to
    /// `WCSession.sendMessage` / `transferUserInfo`. Both APIs require
    /// property-list-safe values, so the packet is JSON-encoded to `Data`
    /// (a valid property-list type) rather than hand-mapped field by field —
    /// this keeps the wire format in one place (`Codable`) instead of two.
    public static let connectivityKey = "pulseboard.metricPacket.v1"

    public func wcSessionPayload() throws -> [String: Any] {
        let data = try JSONEncoder.pulseBoard.encode(self)
        return [Self.connectivityKey: data]
    }

    public static func decode(fromWCSessionPayload dict: [String: Any]) throws -> MetricPacket {
        guard let data = dict[connectivityKey] as? Data else {
            throw ConnectivityPayloadError.missingPayload
        }
        return try JSONDecoder.pulseBoard.decode(MetricPacket.self, from: data)
    }
}

extension WorkoutSummary {
    /// Sent once, when a workout ends, alongside the final `MetricPacket` —
    /// this is the only place the zone-time bar chart's data crosses from
    /// watch to phone, since `MetricPacket` itself carries no zone history.
    public static let connectivityKey = "pulseboard.workoutSummary.v1"

    public func wcSessionPayload() throws -> [String: Any] {
        let data = try JSONEncoder.pulseBoard.encode(self)
        return [Self.connectivityKey: data]
    }

    public static func decode(fromWCSessionPayload dict: [String: Any]) throws -> WorkoutSummary {
        guard let data = dict[connectivityKey] as? Data else {
            throw ConnectivityPayloadError.missingPayload
        }
        return try JSONDecoder.pulseBoard.decode(WorkoutSummary.self, from: data)
    }
}
