import SwiftUI

/// One screen per concept, then a single HealthKit permission sheet (PRD
/// F7) — explains exactly what's read and why before iOS ever shows its
/// own permission prompt.
struct OnboardingView: View {
    @Environment(HealthStore.self) private var healthStore
    var onFinished: () -> Void

    @State private var step = 0
    @State private var isRequestingAuthorization = false

    private let concepts: [OnboardingConcept] = [
        OnboardingConcept(
            systemImage: "waveform.path.ecg",
            title: "Live Heart Rate & Zones",
            body: "PulseBoard reads your heart rate to show a big, live readout and a 5-zone intensity indicator during workouts."
        ),
        OnboardingConcept(
            systemImage: "flame.fill",
            title: "Calories & Activity",
            body: "Active and resting energy let PulseBoard show calories burned live, and answer \"how many calories today\" via Siri."
        ),
        OnboardingConcept(
            systemImage: "figure.run.circle.fill",
            title: "Workouts",
            body: "Workouts you record are saved to Health so they appear in Apple Fitness, and are read back to build your history and summaries."
        ),
        OnboardingConcept(
            systemImage: "lungs.fill",
            title: "Respiratory Rate & More",
            body: "Respiratory rate has no live stream during workouts, so PulseBoard always shows its most recent reading with a timestamp — never a faked live value. VO2 max, resting heart rate, HRV, and step count are also read, for trend views coming later."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $step) {
                welcomeCard.tag(0)
                ForEach(Array(concepts.enumerated()), id: \.offset) { index, concept in
                    conceptCard(concept).tag(index + 1)
                }
                permissionCard.tag(concepts.count + 1)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            if step < concepts.count + 1 {
                Button("Continue") {
                    withAnimation { step += 1 }
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private var welcomeCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 64))
                .foregroundStyle(.red)
            Text("Welcome to PulseBoard")
                .font(.largeTitle.bold())
            Text("A live workout dashboard powered by your Apple Watch. Before you start, here's exactly what health data PulseBoard reads and why.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func conceptCard(_ concept: OnboardingConcept) -> some View {
        VStack(spacing: 16) {
            Image(systemName: concept.systemImage)
                .font(.system(size: 56))
                .foregroundStyle(.red)
            Text(concept.title)
                .font(.title.bold())
            Text(concept.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var permissionCard: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("Ready When You Are")
                .font(.title.bold())
            Text("Next, iOS will ask you to approve access to the health data described above. You can change any of this later in Settings.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button {
                Task {
                    isRequestingAuthorization = true
                    try? await healthStore.requestAuthorization()
                    isRequestingAuthorization = false
                    onFinished()
                }
            } label: {
                if isRequestingAuthorization {
                    ProgressView()
                } else {
                    Text("Enable Health Access")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRequestingAuthorization)
        }
        .padding()
    }
}

private struct OnboardingConcept {
    let systemImage: String
    let title: String
    let body: String
}
