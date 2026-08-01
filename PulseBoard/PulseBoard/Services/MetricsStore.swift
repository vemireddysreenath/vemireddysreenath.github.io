import Foundation
import Observation
import PulseBoardShared

enum WorkoutConnectionState: Equatable {
    /// No workout in progress.
    case idle
    /// Receiving packets within the expected cadence.
    case connected
    /// Was connected but has gone quiet — dashboard shows "Reconnecting…"
    /// per the PRD's disconnect-handling acceptance criterion.
    case reconnecting
}

/// Phone-side landing spot for everything the watch streams over
/// `WatchConnectivity`. `DashboardView` and the Live Activity both read from
/// this single store so they can never show different numbers.
@MainActor
@Observable
final class MetricsStore {
    private(set) var latest: MetricPacket?
    private(set) var connectionState: WorkoutConnectionState = .idle
    private(set) var lastSummary: WorkoutSummary?

    private var staleTimer: Timer?
    /// Generous relative to the ~1 Hz send cadence and the PRD's own "update
    /// at least every 2 seconds" acceptance criterion, so ordinary jitter
    /// never flashes "Reconnecting…".
    private let staleTimeout: TimeInterval = 5.0

    func ingest(_ packet: MetricPacket) {
        latest = packet
        connectionState = (packet.phase == .ended) ? .idle : .connected
        armStaleTimer()
    }

    func ingest(summary: WorkoutSummary) {
        lastSummary = summary
    }

    func acknowledgeSummary() {
        lastSummary = nil
    }

    private func armStaleTimer() {
        staleTimer?.invalidate()
        guard latest?.phase == .running else { return }
        let timer = Timer(timeInterval: staleTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.markStaleIfStillConnected() }
        }
        RunLoop.main.add(timer, forMode: .common)
        staleTimer = timer
    }

    private func markStaleIfStillConnected() {
        guard connectionState == .connected else { return }
        connectionState = .reconnecting
    }
}
