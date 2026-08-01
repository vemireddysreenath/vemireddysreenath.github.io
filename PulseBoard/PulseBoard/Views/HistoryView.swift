import SwiftUI
import HealthKit
import PulseBoardShared

/// Saved workout history backed directly by HealthKit queries — no
/// separate database, per PRD F6.
struct HistoryView: View {
    @Environment(HealthStore.self) private var healthStore
    @State private var workouts: [HKWorkout] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if workouts.isEmpty {
                    ContentUnavailableView(
                        "No Workouts Yet",
                        systemImage: "figure.run",
                        description: Text("Workouts you complete will show up here.")
                    )
                } else {
                    List(workouts, id: \.uuid) { workout in
                        WorkoutHistoryRow(summary: healthStore.summary(for: workout))
                    }
                }
            }
            .navigationTitle("History")
            .task { await loadWorkouts() }
            .refreshable { await loadWorkouts() }
        }
    }

    private func loadWorkouts() async {
        isLoading = true
        workouts = await healthStore.recentWorkouts()
        isLoading = false
    }
}

private struct WorkoutHistoryRow: View {
    let summary: WorkoutSummary

    var body: some View {
        HStack {
            Image(systemName: summary.workoutKind.symbolName)
                .font(.title3)
                .foregroundStyle(.red)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(summary.workoutKind.displayName)
                    .font(.headline)
                Text(summary.startDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(ElapsedTimeFormatter.string(from: summary.duration))
                    .font(.subheadline)
                    .monospacedDigit()
                if let avgHR = summary.avgHR {
                    Text("\(Int(avgHR.rounded())) avg bpm")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
