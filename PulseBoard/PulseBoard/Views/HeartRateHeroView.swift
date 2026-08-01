import SwiftUI
import PulseBoardShared

struct HeartRateHeroView: View {
    let heartRate: Double?
    let zone: HeartRateZone

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(zone.color)
                    .symbolEffect(.pulse, options: .repeating, isActive: heartRate != nil)
                Text(heartRate.map { String(Int($0.rounded())) } ?? "--")
                    .font(.system(size: 110, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            Text("BPM")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(zone.displayName.uppercased())
                .font(.headline)
                .foregroundStyle(zone.color)
        }
        .animation(.easeInOut(duration: 0.3), value: heartRate)
    }
}
