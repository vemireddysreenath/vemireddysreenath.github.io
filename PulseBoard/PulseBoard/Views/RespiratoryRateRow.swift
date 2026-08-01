import SwiftUI
import PulseBoardShared

/// Respiratory rate has no live workout stream (PRD §2.1) — this always
/// shows a recency label rather than implying a live value, and surfaces the
/// denied-permission CTA in place of a value per PRD §2.4.
struct RespiratoryRateRow: View {
    let sample: RespiratoryRateSample?
    let isDenied: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "lungs.fill")
                .foregroundStyle(.cyan)

            if isDenied {
                Text("Respiratory rate unavailable.")
                    .foregroundStyle(.secondary)
                OpenHealthSettingsButton()
                    .font(.footnote.bold())
            } else if let sample {
                Text(sample.displayLabel())
                    .foregroundStyle(.secondary)
            } else {
                Text("No respiratory data yet")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.footnote)
    }
}
