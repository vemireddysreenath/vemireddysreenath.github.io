import SwiftUI
import PulseBoardShared

struct MirrorBanner: View {
    let onMirror: () async -> Void

    var body: some View {
        Button {
            Task { await onMirror() }
        } label: {
            Label("Mirror This Workout", systemImage: "applewatch.radiowaves.left.and.right")
                .font(.footnote.bold())
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)
    }
}

/// Shown instead of the primary hero while in heuristic mirror mode — kept
/// visually distinct from the watch-sourced dashboard so it can never be
/// mistaken for the low-latency live stream.
struct MirroredWorkoutView: View {
    let observer: MirroredWorkoutObserver

    var body: some View {
        VStack(spacing: 14) {
            Label("Mirrored · Higher Latency", systemImage: "applewatch.radiowaves.left.and.right")
                .font(.caption.bold())
                .foregroundStyle(.blue)

            Text(observer.currentHeartRate.map { String(Int($0.rounded())) } ?? "--")
                .font(.system(size: 90, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text("BPM (POLLED)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 32) {
                MetricTile(title: "Elapsed", value: ElapsedTimeFormatter.string(from: observer.elapsed))
                MetricTile(title: "Active Cal", value: CalorieFormatter.string(fromKilocalories: observer.activeCaloriesSinceStart))
            }
        }
    }
}
