import AppIntents
import PulseBoardShared

@MainActor
struct CurrentHeartRateIntent: AppIntent {
    static var title: LocalizedStringResource = "Current Heart Rate"
    static var description = IntentDescription(
        "Reports your current heart rate from an active workout, or your most recent HealthKit reading."
    )

    @Dependency private var metricsStore: MetricsStore
    @Dependency private var healthStore: HealthStore

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        if let packet = metricsStore.latest, packet.phase == .running, let hr = packet.heartRate {
            let bpm = Int(hr.rounded())
            return .result(
                dialog: IntentDialog("Your current heart rate is \(bpm) beats per minute."),
                view: HeartRateSnippetView(bpm: bpm, label: "Live", recency: nil)
            )
        }

        if let sample = await healthStore.latestHeartRateSample() {
            let bpm = Int(sample.value.rounded())
            let recency = RecencyLabelFormatter.label(for: sample.date)
            return .result(
                dialog: IntentDialog("Your most recent heart rate reading was \(bpm) beats per minute, \(recency)."),
                view: HeartRateSnippetView(bpm: bpm, label: "Latest Reading", recency: recency)
            )
        }

        return .result(
            dialog: IntentDialog("I couldn't find a recent heart rate reading."),
            view: HeartRateSnippetView(bpm: nil, label: "No Data", recency: nil)
        )
    }
}
