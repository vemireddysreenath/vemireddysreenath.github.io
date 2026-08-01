import SwiftUI
import PulseBoardShared

struct ZoneIndicatorBar: View {
    let currentZone: HeartRateZone?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(HeartRateZone.allCases.sorted()) { zone in
                RoundedRectangle(cornerRadius: 4)
                    .fill(zone.color.opacity(zone == currentZone ? 1 : 0.25))
                    .frame(height: zone == currentZone ? 14 : 8)
                    .frame(maxWidth: .infinity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: currentZone)
    }
}
