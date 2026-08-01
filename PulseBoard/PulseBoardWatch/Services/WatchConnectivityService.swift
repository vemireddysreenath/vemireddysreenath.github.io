import Foundation
import WatchConnectivity
import Observation
import PulseBoardShared

/// Watch side of the watch → phone metric stream. Sends via `sendMessage`
/// when reachable for the lowest latency, falling back to `transferUserInfo`
/// (queued, delivered even if the phone app isn't foreground) per the PRD.
@MainActor
@Observable
final class WatchConnectivityService: NSObject {
    private(set) var isReachable = false

    /// Fired when the phone pushes a max-HR override via application context.
    var onMaxHRContextReceived: ((Double) -> Void)?

    private var session: WCSession?
    private var lastSendDate: Date?
    private let minimumSendInterval: TimeInterval = 1.0

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.session = session
    }

    /// Steady-state `.running` updates are throttled to ~1 Hz; phase
    /// transitions (paused/ended) always go out immediately so the phone's
    /// "reconnecting…" / summary states never lag behind.
    func send(_ packet: MetricPacket) {
        guard let session, session.activationState == .activated else { return }

        let now = Date()
        if packet.phase == .running,
           let lastSendDate,
           now.timeIntervalSince(lastSendDate) < minimumSendInterval {
            return
        }
        lastSendDate = now

        do {
            let payload = try packet.wcSessionPayload()
            if session.isReachable {
                session.sendMessage(payload, replyHandler: nil) { [weak self] _ in
                    self?.session?.transferUserInfo(payload)
                }
            } else {
                session.transferUserInfo(payload)
            }
        } catch {
            assertionFailure("Failed to encode MetricPacket: \(error)")
        }
    }

    /// Sent once, when a workout ends. Always queued via `transferUserInfo`
    /// (guaranteed, survives the phone app not being foreground) since,
    /// unlike live packets, a dropped final summary can't be superseded by
    /// the next tick — `sendMessage` is only a latency optimization on top.
    func send(_ summary: WorkoutSummary) {
        guard let session, session.activationState == .activated else { return }
        do {
            let payload = try summary.wcSessionPayload()
            session.transferUserInfo(payload)
            if session.isReachable {
                session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
            }
        } catch {
            assertionFailure("Failed to encode WorkoutSummary: \(error)")
        }
    }
}

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let maxHR = applicationContext[ApplicationContextKey.maxHR] as? Double else { return }
        Task { @MainActor in
            self.onMaxHRContextReceived?(maxHR)
        }
    }
}
