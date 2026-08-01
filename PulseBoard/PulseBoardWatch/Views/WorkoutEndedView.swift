import SwiftUI
import PulseBoardShared

struct WorkoutEndedView: View {
    @Environment(WorkoutManager.self) private var workoutManager
    let summary: WorkoutSummary

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green)
                Text("Workout Saved")
                    .font(.headline)

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    GridRow {
                        Text("Duration").foregroundStyle(.secondary)
                        Text(ElapsedTimeFormatter.string(from: summary.duration))
                    }
                    GridRow {
                        Text("Avg HR").foregroundStyle(.secondary)
                        Text(summary.avgHR.map { "\(Int($0.rounded())) bpm" } ?? "--")
                    }
                    GridRow {
                        Text("Calories").foregroundStyle(.secondary)
                        Text(CalorieFormatter.string(fromKilocalories: summary.activeCalories))
                    }
                }
                .font(.footnote)

                Button("Done") {
                    workoutManager.acknowledgeSummary()
                }
                .tint(.green)
            }
            .padding()
        }
    }
}
