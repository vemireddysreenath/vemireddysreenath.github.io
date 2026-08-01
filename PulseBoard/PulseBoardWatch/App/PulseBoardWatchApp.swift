import SwiftUI

@main
struct PulseBoardWatchApp: App {
    @State private var connectivity: WatchConnectivityService
    @State private var workoutManager: WorkoutManager

    init() {
        let connectivity = WatchConnectivityService()
        _connectivity = State(initialValue: connectivity)
        _workoutManager = State(initialValue: WorkoutManager(connectivity: connectivity))
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(workoutManager)
                .environment(connectivity)
        }
    }
}
