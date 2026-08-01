import SwiftUI
import PulseBoardShared

/// Full-screen, high-contrast, glanceable live dashboard (PRD F3) — the
/// primary display during a workout, propped up on a bench or treadmill.
struct DashboardView: View {
    @Environment(MetricsStore.self) private var metricsStore
    @Environment(HealthStore.self) private var healthStore
    @Environment(SettingsStore.self) private var settings
    @Environment(IdleTimerController.self) private var idleTimer
    @Environment(MirroredWorkoutObserver.self) private var mirror

    @State private var respiratorySample: RespiratoryRateSample?

    private var maxHR: Double {
        Double(healthStore.maxHR(overriddenBy: settings.maxHROverride))
    }

    private var currentZone: HeartRateZone? {
        guard let hr = metricsStore.latest?.heartRate else { return nil }
        return HRZoneCalculator.zone(forHeartRate: hr, maxHR: maxHR)
    }

    private var isWorkoutActive: Bool {
        metricsStore.connectionState != .idle
    }

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            ZStack {
                Color.black.ignoresSafeArea()

                Group {
                    if isWorkoutActive {
                        activeLayout(isLandscape: isLandscape)
                    } else if mirror.isMirroring {
                        MirroredWorkoutView(observer: mirror)
                    } else {
                        idleLayout
                    }
                }
                .padding()
                .opacity(settings.dimModeEnabled ? 0.55 : 1)

                VStack {
                    HStack {
                        ConnectionStatusBanner(state: metricsStore.connectionState)
                        Spacer()
                        if idleTimer.isKeepingScreenAwake {
                            AwakeIndicatorBadge()
                        }
                    }
                    Spacer()
                }
                .padding()
            }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
        .onAppear {
            idleTimer.activate()
            mirror.startWatchingForActivity()
        }
        .onDisappear {
            idleTimer.deactivate()
            mirror.stopWatchingForActivity()
        }
        .task { await refreshRespiratoryRate() }
    }

    @ViewBuilder
    private func activeLayout(isLandscape: Bool) -> some View {
        if isLandscape {
            HStack(spacing: 32) {
                HeartRateHeroView(heartRate: metricsStore.latest?.heartRate, zone: currentZone ?? .zone1)
                VStack(spacing: 20) {
                    ZoneIndicatorBar(currentZone: currentZone)
                    statsGrid
                    RespiratoryRateRow(sample: respiratorySample, isDenied: healthStore.isDenied(HealthStore.respiratoryRateType))
                }
            }
        } else {
            VStack(spacing: 24) {
                Spacer(minLength: 0)
                HeartRateHeroView(heartRate: metricsStore.latest?.heartRate, zone: currentZone ?? .zone1)
                ZoneIndicatorBar(currentZone: currentZone)
                statsGrid
                RespiratoryRateRow(sample: respiratorySample, isDenied: healthStore.isDenied(HealthStore.respiratoryRateType))
                Spacer(minLength: 0)
            }
        }
    }

    private var statsGrid: some View {
        let packet = metricsStore.latest
        return VStack(spacing: 16) {
            HStack {
                MetricTile(title: "Elapsed", value: ElapsedTimeFormatter.string(from: packet?.elapsed ?? 0))
                MetricTile(title: "Active Cal", value: CalorieFormatter.string(fromKilocalories: packet?.activeCalories ?? 0))
                MetricTile(title: "Total Cal", value: CalorieFormatter.string(fromKilocalories: packet?.totalCalories ?? 0))
            }
            HStack {
                MetricTile(title: "Min HR", value: packet?.hrMin.map { "\(Int($0.rounded()))" } ?? "--", valueColor: .secondary)
                MetricTile(title: "Avg HR", value: packet?.hrAvg.map { "\(Int($0.rounded()))" } ?? "--", valueColor: .secondary)
                MetricTile(title: "Max HR", value: packet?.hrMax.map { "\(Int($0.rounded()))" } ?? "--", valueColor: .secondary)
            }
            if let distance = packet?.distanceMeters, packet?.workoutKind.tracksDistance == true {
                MetricTile(title: "Distance", value: DistanceFormatter.string(fromMeters: distance))
            }
        }
    }

    private var idleLayout: some View {
        VStack(spacing: 16) {
            Image(systemName: "applewatch")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Start a Workout on Apple Watch")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            Text("The dashboard lights up automatically once your watch starts streaming.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if mirror.recentActivityDetected {
                MirrorBanner {
                    await mirror.startMirroring()
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: 320)
    }

    private func refreshRespiratoryRate() async {
        respiratorySample = await healthStore.latestRespiratoryRateSample()
    }
}
