import AppIntents
import HealthKit
import PulseBoardShared

@MainActor
struct StartWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Start a Workout"
    static var description = IntentDescription("Starts a workout on your Apple Watch.")

    @Parameter(title: "Workout Type", default: .strength)
    var workoutKind: WorkoutKind

    static var parameterSummary: some ParameterSummary {
        Summary("Start a \(\.$workoutKind) workout")
    }

    /// Bridges the classic completion-handler `startWatchApp(with:completion:)`
    /// to async/await, rather than assuming a specific async-native overload
    /// exists on every SDK version this ships against.
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let healthStore = HKHealthStore()
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = workoutKind.healthKitActivityType
        configuration.locationType = workoutKind.tracksDistance ? .outdoor : .indoor

        let started = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            healthStore.startWatchApp(with: configuration) { success, _ in
                continuation.resume(returning: success)
            }
        }

        if started {
            return .result(dialog: IntentDialog("Starting your \(workoutKind.displayName) workout on Apple Watch."))
        } else {
            return .result(
                dialog: IntentDialog(
                    "I couldn't reach your Apple Watch. Make sure it's on your wrist and nearby, then start the workout from the watch app."
                )
            )
        }
    }
}
