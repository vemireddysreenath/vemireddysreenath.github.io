import SwiftUI
import AppIntents

@main
struct PulseBoardApp: App {
    @State private var healthStore: HealthStore
    @State private var metricsStore: MetricsStore
    @State private var settings = SettingsStore()
    @State private var idleTimer = IdleTimerController()
    @State private var liveActivityManager = LiveActivityManager()
    @State private var connectivity: PhoneConnectivityService
    @State private var mirror: MirroredWorkoutObserver

    init() {
        let healthStore = HealthStore()
        let metricsStore = MetricsStore()
        _healthStore = State(initialValue: healthStore)
        _metricsStore = State(initialValue: metricsStore)
        _connectivity = State(initialValue: PhoneConnectivityService(metricsStore: metricsStore))
        _mirror = State(initialValue: MirroredWorkoutObserver(healthStore: healthStore))

        // Lets CurrentHeartRateIntent, TodayCaloriesIntent, etc. (@Dependency)
        // read the same live app state the dashboard does, instead of each
        // intent invocation standing up its own HealthStore/MetricsStore.
        AppDependencyManager.shared.add(dependency: metricsStore)
        AppDependencyManager.shared.add(dependency: healthStore)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(healthStore)
                .environment(metricsStore)
                .environment(settings)
                .environment(idleTimer)
                .environment(liveActivityManager)
                .environment(connectivity)
                .environment(mirror)
        }
    }
}
