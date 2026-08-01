import ActivityKit
import SwiftUI
import WidgetKit
import PulseBoardShared

struct PulseBoardLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PulseBoardActivityAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(
                            context.state.heartRate.map { "\(Int($0.rounded()))" } ?? "--",
                            systemImage: "heart.fill"
                        )
                        .foregroundStyle(context.state.zone?.color ?? .red)
                        .font(.title3.bold())
                        Text("BPM")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(ElapsedTimeFormatter.string(from: context.state.elapsed))
                            .font(.title3.bold())
                            .monospacedDigit()
                        Text(CalorieFormatter.string(fromKilocalories: context.state.activeCalories))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        if let hrMin = context.state.hrMin, let hrMax = context.state.hrMax {
                            HStack {
                                Text("Min \(Int(hrMin.rounded())) · Max \(Int(hrMax.rounded()))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if context.state.phase == .paused {
                                    Text("Paused")
                                        .font(.caption.bold())
                                        .foregroundStyle(.yellow)
                                }
                            }
                        }
                        ZoneIndicatorBar(currentZone: context.state.zone)
                    }
                }
            } compactLeading: {
                Image(systemName: "heart.fill")
                    .foregroundStyle(context.state.zone?.color ?? .red)
            } compactTrailing: {
                Text(context.state.heartRate.map { "\(Int($0.rounded()))" } ?? "--")
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "heart.fill")
                    .foregroundStyle(context.state.zone?.color ?? .red)
            }
            .widgetURL(URL(string: "pulseboard://dashboard"))
            .keylineTint(context.state.zone?.color ?? .red)
        }
    }
}

private struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<PulseBoardActivityAttributes>

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Label(
                    context.state.heartRate.map { "\(Int($0.rounded())) BPM" } ?? "-- BPM",
                    systemImage: "heart.fill"
                )
                .foregroundStyle(context.state.zone?.color ?? .red)
                .font(.title2.bold())
                Text(context.attributes.workoutKind.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(ElapsedTimeFormatter.string(from: context.state.elapsed))
                    .font(.title3.bold())
                    .monospacedDigit()
                Text(CalorieFormatter.string(fromKilocalories: context.state.activeCalories))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
