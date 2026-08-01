import SwiftUI

/// The PRD requires every screen to offer a clear CTA to Settings when a
/// HealthKit permission is denied (§2.4) — this is that CTA, reused wherever
/// a denied-permission state is shown.
struct OpenHealthSettingsButton: View {
    var title: String = "Enable in Settings"

    var body: some View {
        Button(title) {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    }
}
