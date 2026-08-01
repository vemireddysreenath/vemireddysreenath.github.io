import SwiftUI
import PulseBoardShared

/// Deliberately minimal — the iPhone dashboard (Live Activity when
/// backgrounded) is the primary display per the PRD; this view only needs
/// to support "prop the phone up and forget the watch."
struct WorkoutSessionView: View {
    @Environment(WorkoutManager.self) private var workoutManager

    var body: some View {
        VStack(spacing: 6) {
            Text(ElapsedTimeFormatter.string(from: workoutManager.elapsed))
                .font(.system(.title3, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                    .font(.title3)
                Text(workoutManager.currentHeartRate.map { String(Int($0.rounded())) } ?? "--")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }

            Text(CalorieFormatter.string(fromKilocalories: workoutManager.activeCalories))
                .font(.headline)
                .foregroundStyle(.secondary)

            if workoutManager.phase == .paused {
                Text("Paused")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }

            Spacer(minLength: 4)

            HStack(spacing: 8) {
                Button {
                    workoutManager.phase == .paused ? workoutManager.resume() : workoutManager.pause()
                } label: {
                    Image(systemName: workoutManager.phase == .paused ? "play.fill" : "pause.fill")
                }
                .tint(.yellow)

                Button(role: .destructive) {
                    workoutManager.endWorkout()
                } label: {
                    Image(systemName: "stop.fill")
                }
                .tint(.red)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 4)
    }
}
