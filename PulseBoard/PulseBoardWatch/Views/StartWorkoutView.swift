import SwiftUI
import PulseBoardShared

struct StartWorkoutView: View {
    @Environment(WorkoutManager.self) private var workoutManager

    var body: some View {
        List(WorkoutKind.allCases) { kind in
            Button {
                workoutManager.startWorkout(kind: kind)
            } label: {
                Label(kind.displayName, systemImage: kind.symbolName)
            }
        }
        .navigationTitle("PulseBoard")
        .alert(
            "Something Went Wrong",
            isPresented: Binding(
                get: { workoutManager.lastErrorMessage != nil },
                set: { isPresented in
                    if !isPresented { workoutManager.lastErrorMessage = nil }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(workoutManager.lastErrorMessage ?? "")
        }
    }
}
