import AppIntents
import PulseBoardShared

@MainActor
struct LastWorkoutDurationIntent: AppIntent {
    static var title: LocalizedStringResource = "Last Workout's Duration"
    static var description = IntentDescription("Reports how long your most recent workout lasted.")

    @Dependency private var healthStore: HealthStore

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        guard let workout = await healthStore.recentWorkouts(limit: 1).first else {
            return .result(
                dialog: IntentDialog("I couldn't find a recent workout."),
                view: StatSnippetView(title: "Last Workout", value: "--", subtitle: nil, systemImage: "clock.fill")
            )
        }

        let summary = healthStore.summary(for: workout)
        let durationText = ElapsedTimeFormatter.string(from: summary.duration)
        let minutes = max(1, Int(summary.duration / 60))

        return .result(
            dialog: IntentDialog("Your last \(summary.workoutKind.displayName) workout lasted about \(minutes) minutes."),
            view: StatSnippetView(
                title: summary.workoutKind.displayName,
                value: durationText,
                subtitle: "Duration",
                systemImage: "clock.fill"
            )
        )
    }
}
