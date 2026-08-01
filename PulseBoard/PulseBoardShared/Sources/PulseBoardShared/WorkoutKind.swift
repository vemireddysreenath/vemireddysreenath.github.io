import Foundation

/// Workout types offered by PulseBoard. Deliberately a small, app-owned enum
/// (rather than passing `HKWorkoutActivityType` around) so the shared package
/// stays portable and Codable-stable across app versions. Map to/from
/// `HKWorkoutActivityType` at the HealthKit boundary in the watch app.
public enum WorkoutKind: String, Codable, CaseIterable, Sendable, Identifiable, Hashable {
    case strength
    case running
    case walking
    case cycling
    case hiit
    case yoga
    case other

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .strength: return "Strength"
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .hiit: return "HIIT"
        case .yoga: return "Yoga"
        case .other: return "Other"
        }
    }

    /// SF Symbol name for use in both watch and phone UI.
    public var symbolName: String {
        switch self {
        case .strength: return "dumbbell.fill"
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .cycling: return "figure.outdoor.cycle"
        case .hiit: return "figure.highintensity.intervaltraining"
        case .yoga: return "figure.yoga"
        case .other: return "figure.mixed.cardio"
        }
    }

    /// Whether this workout kind reports a meaningful distance metric.
    public var tracksDistance: Bool {
        switch self {
        case .running, .walking, .cycling:
            return true
        case .strength, .hiit, .yoga, .other:
            return false
        }
    }
}
