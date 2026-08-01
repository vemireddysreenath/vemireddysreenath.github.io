import AppIntents
import PulseBoardShared

// Retroactive AppEnum conformance for the shared WorkoutKind, kept here
// (rather than in PulseBoardShared) since AppIntents doesn't exist on
// watchOS and the shared package targets both platforms.
extension WorkoutKind: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Workout Type")
    }

    static var caseDisplayRepresentations: [WorkoutKind: DisplayRepresentation] {
        [
            .strength: DisplayRepresentation(title: "Strength"),
            .running: DisplayRepresentation(title: "Running"),
            .walking: DisplayRepresentation(title: "Walking"),
            .cycling: DisplayRepresentation(title: "Cycling"),
            .hiit: DisplayRepresentation(title: "HIIT"),
            .yoga: DisplayRepresentation(title: "Yoga"),
            .other: DisplayRepresentation(title: "Other")
        ]
    }
}
