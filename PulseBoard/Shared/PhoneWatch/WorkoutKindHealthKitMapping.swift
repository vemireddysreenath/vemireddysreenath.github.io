import HealthKit
import PulseBoardShared

// Shared by the iOS and watchOS targets (not the portable PulseBoardShared
// package, since that stays HealthKit-free so it can build/test on any
// platform). Symbolic HKWorkoutActivityType cases only — never raw values —
// so this can't silently drift from the SDK's real numbering.
extension WorkoutKind {
    var healthKitActivityType: HKWorkoutActivityType {
        switch self {
        case .strength: return .traditionalStrengthTraining
        case .running: return .running
        case .walking: return .walking
        case .cycling: return .cycling
        case .hiit: return .highIntensityIntervalTraining
        case .yoga: return .yoga
        case .other: return .other
        }
    }

    init(healthKitActivityType type: HKWorkoutActivityType) {
        switch type {
        case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining:
            self = .strength
        case .running:
            self = .running
        case .walking:
            self = .walking
        case .cycling:
            self = .cycling
        case .highIntensityIntervalTraining:
            self = .hiit
        case .yoga:
            self = .yoga
        default:
            self = .other
        }
    }
}
