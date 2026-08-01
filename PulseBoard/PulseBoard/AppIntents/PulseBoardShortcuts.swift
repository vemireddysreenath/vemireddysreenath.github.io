import AppIntents

struct PulseBoardShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CurrentHeartRateIntent(),
            phrases: [
                "What's my heart rate in \(.applicationName)",
                "Check my heart rate with \(.applicationName)",
                "What's my current heart rate in \(.applicationName)"
            ],
            shortTitle: "Current Heart Rate",
            systemImageName: "heart.fill"
        )
        AppShortcut(
            intent: TodayCaloriesIntent(),
            phrases: [
                "How many calories have I burned today in \(.applicationName)",
                "Check today's calories with \(.applicationName)"
            ],
            shortTitle: "Calories Today",
            systemImageName: "flame.fill"
        )
        AppShortcut(
            intent: LastWorkoutMaxHeartRateIntent(),
            phrases: [
                "What was my max heart rate in \(.applicationName)",
                "Check my last workout's max heart rate in \(.applicationName)"
            ],
            shortTitle: "Last Workout Max HR",
            systemImageName: "heart.fill"
        )
        AppShortcut(
            intent: LastWorkoutDurationIntent(),
            phrases: [
                "How long was my last workout in \(.applicationName)",
                "Check my last workout duration with \(.applicationName)"
            ],
            shortTitle: "Last Workout Duration",
            systemImageName: "clock.fill"
        )
        AppShortcut(
            intent: StartWorkoutIntent(),
            phrases: [
                "Start a workout with \(.applicationName)",
                "Start my workout in \(.applicationName)"
            ],
            shortTitle: "Start Workout",
            systemImageName: "figure.run"
        )
    }
}
