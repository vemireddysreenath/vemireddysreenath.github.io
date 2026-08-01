import SwiftUI
import PulseBoardShared

struct RootView: View {
    @Environment(HealthStore.self) private var healthStore
    @Environment(MetricsStore.self) private var metricsStore
    @Environment(SettingsStore.self) private var settings
    @Environment(LiveActivityManager.self) private var liveActivityManager
    @Environment(PhoneConnectivityService.self) private var connectivity

    @AppStorage("onboarding.completed") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            }
        }
        .sheet(item: summaryBinding) { summary in
            SummaryView(summary: summary) {
                metricsStore.acknowledgeSummary()
            }
        }
        .onChange(of: metricsStore.latest) { _, newValue in
            guard let newValue else { return }
            let maxHR = Double(healthStore.maxHR(overriddenBy: settings.maxHROverride))
            liveActivityManager.handle(packet: newValue, maxHR: maxHR)
        }
        .task {
            let maxHR = healthStore.maxHR(overriddenBy: settings.maxHROverride)
            connectivity.pushMaxHRSetting(maxHR)
        }
    }

    private var summaryBinding: Binding<WorkoutSummary?> {
        Binding(
            get: { metricsStore.lastSummary },
            set: { newValue in
                if newValue == nil { metricsStore.acknowledgeSummary() }
            }
        )
    }
}
