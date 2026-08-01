import SwiftUI
import HealthKit
import PulseBoardShared

struct SettingsView: View {
    @Environment(HealthStore.self) private var healthStore
    @Environment(SettingsStore.self) private var settings
    @Environment(PhoneConnectivityService.self) private var connectivity

    @State private var maxHRText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Max Heart Rate") {
                    HStack {
                        Text("Override")
                        Spacer()
                        TextField("Auto", text: $maxHRText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    Text("Defaults to 220 minus your age from Health. Leave blank to use the default.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Display") {
                    Toggle(
                        "Dim Mode",
                        isOn: Binding(get: { settings.dimModeEnabled }, set: { settings.dimModeEnabled = $0 })
                    )
                    Text("Reduces dashboard brightness for long sessions. The screen still won't lock.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Health Access") {
                    ForEach(HealthPermissionKind.allCases) { kind in
                        HStack {
                            Text(kind.title)
                            Spacer()
                            if healthStore.isDenied(kind.objectType) {
                                Label("Denied", systemImage: "xmark.circle.fill")
                                    .labelStyle(.iconOnly)
                                    .foregroundStyle(.red)
                            } else {
                                Label("OK", systemImage: "checkmark.circle.fill")
                                    .labelStyle(.iconOnly)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    OpenHealthSettingsButton(title: "Open Health Settings")
                }

                Section("Apple Watch") {
                    LabeledContent("Reachable", value: connectivity.isWatchAppReachable ? "Yes" : "No")
                    LabeledContent("Watch App Installed", value: connectivity.isWatchAppInstalled ? "Yes" : "No")
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                maxHRText = settings.maxHROverride.map(String.init) ?? ""
                healthStore.refreshAuthorizationStatuses()
            }
            .onChange(of: maxHRText) { _, newValue in
                if let value = Int(newValue), value > 0 {
                    settings.maxHROverride = value
                    connectivity.pushMaxHRSetting(value)
                } else if newValue.isEmpty {
                    settings.maxHROverride = nil
                    connectivity.pushMaxHRSetting(healthStore.maxHR(overriddenBy: nil))
                }
            }
        }
    }
}

private enum HealthPermissionKind: CaseIterable, Identifiable, Hashable {
    case heartRate, activeEnergy, basalEnergy, respiratoryRate, workouts
    case vo2Max, restingHeartRate, hrv, stepCount, distance, dateOfBirth

    var id: Self { self }

    var title: String {
        switch self {
        case .heartRate: return "Heart Rate"
        case .activeEnergy: return "Active Energy"
        case .basalEnergy: return "Resting Energy"
        case .respiratoryRate: return "Respiratory Rate"
        case .workouts: return "Workouts"
        case .vo2Max: return "VO2 Max"
        case .restingHeartRate: return "Resting Heart Rate"
        case .hrv: return "Heart Rate Variability"
        case .stepCount: return "Step Count"
        case .distance: return "Distance"
        case .dateOfBirth: return "Date of Birth"
        }
    }

    var objectType: HKObjectType {
        switch self {
        case .heartRate: return HealthStore.heartRateType
        case .activeEnergy: return HealthStore.activeEnergyType
        case .basalEnergy: return HealthStore.basalEnergyType
        case .respiratoryRate: return HealthStore.respiratoryRateType
        case .workouts: return HealthStore.workoutType
        case .vo2Max: return HealthStore.vo2MaxType
        case .restingHeartRate: return HealthStore.restingHeartRateType
        case .hrv: return HealthStore.hrvType
        case .stepCount: return HealthStore.stepCountType
        case .distance: return HealthStore.distanceWalkingRunningType
        case .dateOfBirth: return HealthStore.dateOfBirthType
        }
    }
}
