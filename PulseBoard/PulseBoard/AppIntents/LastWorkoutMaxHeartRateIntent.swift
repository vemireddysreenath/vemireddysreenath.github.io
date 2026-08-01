import AppIntents
import PulseBoardShared

@MainActor
struct LastWorkoutMaxHeartRateIntent: AppIntent {
    static var title: LocalizedStringResource = "Last Workout's Max Heart Rate"
    static var description = IntentDescription("Reports the highest heart rate recorded during your most recent workout.")

    @Dependency private var healthStore: HealthStore

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        guard let workout = await healthStore.recentWorkouts(limit: 1).first else {
            return .result(
                dialog: IntentDialog("I couldn't find a recent workout."),
                view: StatSnippetView(title: "Max Heart Rate", value: "--", subtitle: nil, systemImage: "heart.fill")
            )
        }

        let summary = healthStore.summary(for: workout)
        guard let maxHR = summary.maxHR else {
            return .result(
                dialog: IntentDialog("Your last workout didn't record heart rate data."),
                view: StatSnippetView(
                    title: "Max Heart Rate",
                    value: "--",
                    subtitle: summary.workoutKind.displayName,
                    systemImage: "heart.fill"
                )
            )
        }

        let bpm = Int(maxHR.rounded())
        return .result(
            dialog: IntentDialog(
                "Your max heart rate in your last \(summary.workoutKind.displayName) workout was \(bpm) beats per minute."
            ),
            view: StatSnippetView(
                title: "Max Heart Rate",
                value: "\(bpm) BPM",
                subtitle: summary.workoutKind.displayName,
                systemImage: "heart.fill"
            )
        )
    }
}
