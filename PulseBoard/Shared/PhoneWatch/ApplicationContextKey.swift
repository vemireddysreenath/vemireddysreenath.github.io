import Foundation

/// Keys for `WCSession.updateApplicationContext`, the low-frequency settings
/// channel (as opposed to `MetricPacket`'s high-frequency message channel).
/// Lives in the cross-target `Shared/` folder — included in both the iOS and
/// watchOS app targets directly — so the two connectivity services can't
/// drift apart on the key string.
enum ApplicationContextKey {
    static let maxHR = "pulseboard.settings.maxHR"
}
