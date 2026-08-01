import SwiftUI
import PulseBoardShared

// Shared by the iOS app target and the Live Activity widget extension (not
// the portable PulseBoardShared package, which stays SwiftUI-free). A plain
// switch over the enum keeps this exhaustive at compile time — adding a
// 6th zone someday would fail to build here instead of silently falling
// back to a default color.
extension HeartRateZone {
    var color: Color {
        switch self {
        case .zone1: return .blue
        case .zone2: return .green
        case .zone3: return .yellow
        case .zone4: return .orange
        case .zone5: return .red
        }
    }
}
