import SwiftUI

struct WatchRootView: View {
    @Environment(WorkoutManager.self) private var workoutManager

    var body: some View {
        Group {
            if let summary = workoutManager.lastSummary {
                WorkoutEndedView(summary: summary)
            } else if workoutManager.workoutKind != nil {
                WorkoutSessionView()
            } else {
                StartWorkoutView()
            }
        }
        .task {
            await workoutManager.requestAuthorization()
        }
    }
}
