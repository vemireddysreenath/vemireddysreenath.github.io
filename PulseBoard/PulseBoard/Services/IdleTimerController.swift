import UIKit
import Observation

/// Reference-counted wrapper around `UIApplication.isIdleTimerDisabled`.
/// Counting (rather than a plain bool) means an overlapping appear/disappear
/// during a SwiftUI navigation transition can't have one view's `.onDisappear`
/// re-enable the lock screen while another view still wants it held off.
@MainActor
@Observable
final class IdleTimerController {
    private(set) var isKeepingScreenAwake = false
    private var activationCount = 0

    func activate() {
        activationCount += 1
        applyState()
    }

    func deactivate() {
        activationCount = max(0, activationCount - 1)
        applyState()
    }

    private func applyState() {
        let shouldStayAwake = activationCount > 0
        guard shouldStayAwake != isKeepingScreenAwake else { return }
        isKeepingScreenAwake = shouldStayAwake
        UIApplication.shared.isIdleTimerDisabled = shouldStayAwake
    }
}
