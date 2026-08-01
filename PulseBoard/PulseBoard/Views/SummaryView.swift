import SwiftUI
import Charts
import PulseBoardShared

/// Shown once a workout ends (PRD F6). The zone-time bar chart uses the
/// `WorkoutSummary` the watch computed live during the session — the only
/// place that data exists, since it isn't reconstructed for older history.
struct SummaryView: View {
    let summary: WorkoutSummary
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    metricsGrid
                    if summary.zoneDistribution.contains(where: { $0.duration > 0 }) {
                        zoneChart
                    }
                }
                .padding()
            }
            .navigationTitle(summary.workoutKind.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary.startDate, style: .date)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(ElapsedTimeFormatter.string(from: summary.duration))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
    }

    private var metricsGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 20) {
            GridRow {
                MetricTile(title: "Avg HR", value: summary.avgHR.map { "\(Int($0.rounded()))" } ?? "--")
                MetricTile(title: "Min HR", value: summary.minHR.map { "\(Int($0.rounded()))" } ?? "--")
                MetricTile(title: "Max HR", value: summary.maxHR.map { "\(Int($0.rounded()))" } ?? "--")
            }
            GridRow {
                MetricTile(title: "Active Cal", value: CalorieFormatter.string(fromKilocalories: summary.activeCalories))
                MetricTile(title: "Total Cal", value: CalorieFormatter.string(fromKilocalories: summary.totalCalories))
                if let distance = summary.distanceMeters {
                    MetricTile(title: "Distance", value: DistanceFormatter.string(fromMeters: distance))
                } else {
                    Color.clear
                }
            }
        }
    }

    private var zoneChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Time in Zone")
                .font(.headline)
            Chart(summary.zoneDistribution) { entry in
                BarMark(
                    x: .value("Minutes", entry.duration / 60),
                    y: .value("Zone", "Zone \(entry.zone.rawValue)")
                )
                .foregroundStyle(entry.zone.color)
            }
            .frame(height: 180)
        }
    }
}
