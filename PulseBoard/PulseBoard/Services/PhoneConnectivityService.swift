import Foundation
import WatchConnectivity
import Observation
import PulseBoardShared

/// Phone side of `WatchConnectivity`: receives the live metric stream and
/// the end-of-workout summary, and pushes the user's max-HR override to the
/// watch so both sides bucket HR zones identically.
@MainActor
@Observable
final class PhoneConnectivityService: NSObject {
    private(set) var isWatchAppReachable = false
    private(set) var isWatchAppInstalled = false

    private var session: WCSession?
    private let metricsStore: MetricsStore

    init(metricsStore: MetricsStore) {
        self.metricsStore = metricsStore
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.session = session
    }

    func pushMaxHRSetting(_ maxHR: Int) {
        guard let session, session.activationState == .activated else { return }
        do {
            try session.updateApplicationContext([ApplicationContextKey.maxHR: Double(maxHR)])
        } catch {
            assertionFailure("Failed to push maxHR application context: \(error)")
        }
    }

    private func handleIncoming(_ payload: [String: Any]) {
        if let packet = try? MetricPacket.decode(fromWCSessionPayload: payload) {
            metricsStore.ingest(packet)
        }
        if let summary = try? WorkoutSummary.decode(fromWCSessionPayload: payload) {
            metricsStore.ingest(summary: summary)
        }
    }
}

extension PhoneConnectivityService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.isWatchAppReachable = session.isReachable
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
    }

    /// iOS-only pair of callbacks (a watch app has no equivalent, since
    /// there's exactly one phone). Reactivating on deactivate is Apple's
    /// documented pattern for supporting a user switching between paired
    /// Watches.
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchAppReachable = session.isReachable
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in self.handleIncoming(message) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in self.handleIncoming(userInfo) }
    }
}
