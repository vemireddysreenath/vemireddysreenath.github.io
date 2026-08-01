import SwiftUI

/// Small, reused visual snippets for Siri's "spoken + visual" intent
/// responses (PRD F5) — deliberately plain so they render well in Siri's
/// compact snippet card.
struct HeartRateSnippetView: View {
    let bpm: Int?
    let label: String
    let recency: String?

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "heart.fill").foregroundStyle(.red)
                Text(bpm.map(String.init) ?? "--")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                Text("BPM").font(.headline).foregroundStyle(.secondary)
            }
            Text(recency.map { "\(label) · \($0)" } ?? label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

struct StatSnippetView: View {
    let title: String
    let value: String
    let subtitle: String?
    var systemImage: String = "figure.run"

    var body: some View {
        VStack(spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 40, weight: .bold, design: .rounded))
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
