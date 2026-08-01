import Foundation
import Observation

/// User-adjustable settings that affect HR zone math and dashboard display.
/// `maxHROverride`, when set, is pushed to the watch via
/// `PhoneConnectivityService.pushMaxHRSetting` so live zone bucketing on
/// both devices always agrees.
@MainActor
@Observable
final class SettingsStore {
    var maxHROverride: Int? {
        didSet {
            if let maxHROverride {
                defaults.set(maxHROverride, forKey: Keys.maxHROverride)
            } else {
                defaults.removeObject(forKey: Keys.maxHROverride)
            }
        }
    }

    /// Reduced-brightness dashboard for long sessions, per PRD §4.4 — the
    /// idle timer stays disabled either way.
    var dimModeEnabled: Bool {
        didSet { defaults.set(dimModeEnabled, forKey: Keys.dimModeEnabled) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let maxHROverride = "settings.maxHROverride"
        static let dimModeEnabled = "settings.dimModeEnabled"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.maxHROverride = defaults.object(forKey: Keys.maxHROverride) as? Int
        self.dimModeEnabled = defaults.bool(forKey: Keys.dimModeEnabled)
    }
}
