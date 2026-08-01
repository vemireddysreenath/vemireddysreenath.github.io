import SwiftUI

struct ConnectionStatusBanner: View {
    let state: WorkoutConnectionState

    var body: some View {
        if state == .reconnecting {
            Label("Reconnecting to Apple Watch…", systemImage: "exclamationmark.arrow.triangle.2.circlepath")
                .font(.footnote.bold())
                .foregroundStyle(.yellow)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(.yellow.opacity(0.15), in: Capsule())
                .transition(.opacity)
        }
    }
}

struct AwakeIndicatorBadge: View {
    var body: some View {
        Label("Screen Staying Awake", systemImage: "eye.fill")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
}
